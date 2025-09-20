package event

import (
	"net/url"
	"std"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	eve "gno.land/p/eve000/event/component"
)

// -----------------------------------------------------------------------------
// CalendarApp (the main application state)
// -----------------------------------------------------------------------------

type CalendarApp struct {
	// Storage (single source of truth)
	objectStore *avl.Tree // key: cid -> value: eve.Record
	// Lightweight indices (CIDs only)
	EventCalendarIndex *avl.Tree // key: cid -> value: cid
	eventIndex         *avl.Tree // key: cid -> value: cid

	// Sequencing
	counter eve.Counter

	// Validation config
	requiredLDCols []string

	// Defaults / seeds
	defaultSchedule Schedule
	eventCalendar   EventCalendar
	defaultEventCid string

	// Injected UI hooks (optional)
	// CommentForm renders the per-event proposal/comment form.
	// Signature matches old free function: func(cid string, event Schedule) string
	CommentForm func(string, Schedule) string

	// EditableForm renders the "register projection" form when an object implements eve.Editable.
	// If nil, we fall back to calling ed.RenderForm(path) when available.
	EditableForm func(eve.Editable, string) string
}

// -----------------------------------------------------------------------------
// Functional options for CalendarApp
// -----------------------------------------------------------------------------

type CalendarOption func(*CalendarApp)

func WithCommentForm(f func(string, Schedule) string) CalendarOption {
	return func(a *CalendarApp) { a.CommentForm = f }
}

// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------

// Calendar builds a fresh CalendarApp and seeds the EventCalendar + one event.
// Accepts:
//   - opts map for default schedule overrides
//   - optFns functional options (e.g., WithCommentForm, WithEditableForm)
func Calendar(opts map[string]string, optFns ...CalendarOption) *CalendarApp {
	a := &CalendarApp{
		objectStore:        avl.NewTree(),
		EventCalendarIndex: avl.NewTree(),
		eventIndex:         avl.NewTree(),
		requiredLDCols:     []string{"name", "description"},
		defaultSchedule: Schedule{
			Status:      "EventScheduled",
			StartDate:   "2025-01-01T10:20:00Z",
			EndDate:     "2025-01-01T11:20:00Z",
			Title:       "",
			Description: "",
		},
		// sensible defaults (can be overridden by options)
		CommentForm:  defaultCommentForm,
		EditableForm: nil, // fallback to ed.RenderForm if not provided
	}

	// Apply schedule field overrides via opts map
	if opts != nil {
		if v, ok := opts["Status"]; ok {
			a.defaultSchedule.Status = v
		}
		if v, ok := opts["StartDate"]; ok {
			a.defaultSchedule.StartDate = v
		}
		if v, ok := opts["EndDate"]; ok {
			a.defaultSchedule.EndDate = v
		}
		if v, ok := opts["Title"]; ok {
			a.defaultSchedule.Title = v
		}
		if v, ok := opts["Description"]; ok {
			a.defaultSchedule.Description = v
		}
	}

	// Apply functional options
	for _, fn := range optFns {
		fn(a)
	}

	// Seed an EventCalendar that carries its own default schedule.
	a.eventCalendar = EventCalendar{
		Title:   a.defaultSchedule.Title,
		Events:  avl.NewTree(),
		Default: a.defaultSchedule,
	}

	// Register EventCalendar and one example event, and index them.
	a.Register(a.eventCalendar, func(rec eve.Record) {
		cal := rec.Object.(EventCalendar)
		evtCid := a.Register(cal.Event(rec.Cid))
		a.defaultEventCid = evtCid

		// EventCalendar tracks only the event CID (no duplication of Schedule).
		cal.Events.Set(evtCid, evtCid)
	})

	return a
}

// -----------------------------------------------------------------------------
// Small helpers (now methods on *CalendarApp)
// -----------------------------------------------------------------------------

func (a *CalendarApp) seqNext() (n int64, s string) {
	n = a.counter.Bump()
	return n, ufmt.Sprintf("%08d", n)
}

func (a *CalendarApp) getRecord(cid string) (eve.Record, bool) {
	if v, ok := a.objectStore.Get(cid); ok {
		if r, ok2 := v.(eve.Record); ok2 {
			return r, true
		}
	}
	return eve.Record{}, false
}

// -----------------------------------------------------------------------------
// Register (method)
// -----------------------------------------------------------------------------

// Register adds a LogoGraph object to the store and indexes it by type.
func (a *CalendarApp) Register(obj interface{}, cb ...func(rec eve.Record)) string {
	lg, ok := obj.(eve.LogoGraph)
	if !ok {
		panic("object must implement eve.LogoGraph interface")
	}

	newCid := lg.Cid()
	eve.MustCIDv1("object CID", newCid)

	// Law check: projection round-trip
	eve.AssertProjectionRoundTrip(obj, lg)

	// Smoke-test media
	_ = lg.SVG()
	_ = lg.Thumbnail()

	ld := lg.JsonLD()
	for _, col := range a.requiredLDCols {
		if _, ok := ld[col]; !ok {
			panic("object JSON-LD must include " + col)
		}
	}

	if _, exists := a.objectStore.Get(newCid); exists {
		panic("duplicate CID registered: " + newCid)
	}

	seq, seqStr := a.seqNext()
	rec := eve.Record{
		Name:        ld.StringVal("name"),
		Description: ld.StringVal("description"),
		Cid:         newCid,
		Object:      obj,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         seq,
	}

	// Store exactly once.
	a.objectStore.Set(rec.Cid, rec)
	std.Emit("Register", "cid", rec.Cid, "seq", seqStr)

	switch obj.(type) {
	case EventCalendar:
		a.EventCalendarIndex.Set(rec.Cid, rec.Cid)
	case Schedule:
		a.eventIndex.Set(rec.Cid, rec.Cid)
	}

	for _, f := range cb {
		f(rec)
	}
	return newCid
}

// -----------------------------------------------------------------------------
// Render router (method)
// -----------------------------------------------------------------------------

func Info(msg ...string) string {
	var sb strings.Builder
	sb.WriteString("\n\n>[!INFO]\n")
	for _, line := range msg {
		sb.WriteString(">\n> " + line + "\n")
	}
	return sb.String()
}

func (a *CalendarApp) Render(path string) string {
	q := eve.ParseQuery(path)

	// Object route: ?cal=<EventCalendarCid>&obj=<objectCid>
	if cal, hasCal := q["cal"]; hasCal && len(cal) == 1 {
		if obj, hasCid := q["obj"]; hasCid && len(obj) == 1 {
			rec, ok := a.getRecord(obj[0])
			if !ok {
				return a.renderEventCalendarTable() +
					Info(
						"The link you followed does not point to an on-chain event.",
						"If you expected to see an event, please check with the event organizer.",
					)
			}
			lg, projected, ok := eve.AsLogoGraph(rec.Object, path)
			if !ok {
				return "object is not renderable (no eve.LogoGraph)"
			}
			return a.renderObject(rec, lg, projected)
		}
	}

	// EventCalendar route: ?cal=<EventCalendarCid>[&cid=<eventCid>]
	if cal, hasCal := q["cal"]; hasCal && len(cal) == 1 {
		if rec, ok := a.getRecord(cal[0]); ok {
			if c, ok := rec.Object.(EventCalendar); ok {
				if event, hasEvt := q["cid"]; hasEvt && len(event) == 1 {
					if _, ok := c.Events.Get(event[0]); ok {
						if evtRec, ok := a.getRecord(event[0]); ok {
							return a.renderEvent(path, evtRec.Object)
						}
						return "event (cid) not found in object store: " + event[0]
					}
					return "event cid not found in EventCalendar: " + event[0]
				}
				return a.renderEventCalendar(c)
			}
			return "invalid EventCalendar record"
		}
		return "cal cid not found: " + cal[0]
	}

	// Global routes
	if _, hasCid := q["cid"]; !hasCid {
		if v, ok := q["v"]; ok && len(v) == 1 && v[0] == "seq" {
			return a.counter.String()
		}
		return a.renderEventCalendarTable()
	}

	// Optional: projection registration form (injected or fallback)
	if submit, ok := q["submit"]; ok && len(submit) > 0 && submit[0] == "register" {
		if base, ok := q["base"]; ok && len(base) > 0 && eve.IsCIDv1(base[0]) {
			if r, ok := a.getRecord(base[0]); ok {
				if ed, isEd := r.Object.(eve.Editable); isEd {
					// Prefer injected form renderer if provided
					if a.EditableForm != nil {
						if form := a.EditableForm(ed, path); form != "" {
							return form
						}
					}
					// Fallback to the object's own method
					if form := ed.RenderForm(path); form != "" {
						return form
					}
				}
				return "base object is not editable"
			}
			return "base cid not found: " + base[0]
		}
		return "missing or invalid base parameter"
	}

	// Resolve CID & possibly project it from the path
	cid := q["cid"][0]
	rec, ok := a.getRecord(cid)
	if !ok {
		return "cid not found"
	}

	lg, projected, ok := eve.AsLogoGraph(rec.Object, path)
	if !ok {
		return "object is not renderable (no LogoGraph)"
	}

	// Structured views via v={ldjson|cid|seq|committer|svg|thumbnail|json}
	if v, hasV := q["v"]; hasV && len(v) == 1 {
		switch v[0] {
		case "ldjson":
			ld := lg.JsonLD()
			if ldjson, ok := q["ldjson"]; ok && len(ldjson) == 1 {
				parts := strings.Split(ldjson[0], ".")
				val := interface{}(ld)
				for _, p := range parts {
					if m, ok := val.(eve.JsonLDMap); ok {
						val = m[p]
					} else {
						return ""
					}
				}
				if s, ok := val.(string); ok {
					return s
				}
				return ufmt.Sprintf("%v", val)
			}
			return ld.String()
		case "cid":
			x := lg.JsonLD().Cid()
			return "[" + x + "](?cid=" + x + ")"
		case "seq":
			return ufmt.Sprintf("%d", rec.Seq)
		case "committer":
			return rec.Committer
		case "svg":
			return lg.SVG()
		case "thumbnail":
			return lg.Thumbnail()
		case "json":
			return lg.JsonLD().String()
		}
	}

	// Optional seal verification
	if seal, ok := q["seal"]; ok && len(seal) == 1 {
		eve.MustCIDv1("seal", seal[0])
		calc := lg.JsonLD().Cid()
		if seal[0] != calc {
			return "invalid seal: expected " + calc + " but got " + seal[0]
		}
	}

	return a.renderObject(rec, lg, projected)
}

// -----------------------------------------------------------------------------
// Render helpers
// -----------------------------------------------------------------------------

func (a *CalendarApp) renderEvent(path string, obj interface{}) string {
	event, ok := obj.(Schedule)
	if !ok {
		return "object is not a scheduled event"
	}
	event = event.FromPath(path).(Schedule)
	eventCid := event.Cid()

	var sb strings.Builder
	sb.WriteString(event.Thumbnail() + "\n\n")
	sb.WriteString(event.Description + "\n\n")

	sb.WriteString("**CID:** [" + eventCid[len(eventCid)-8:] + "](?obj=" + eventCid + "&cal=" + event.EventCalendarCid + ")\n\n")
	sb.WriteString("**Status:** " + event.Status + "\n\n")
	sb.WriteString("**Date:** " + event.StartDate[:10] + "\n\n")
	sb.WriteString("**Time:** " + event.StartDate[11:16] + " to " + event.EndDate[11:16] + " UTC\n\n")
	if event.EventCalendarCid != "" {
		sb.WriteString("[← EventCalendar" + "](?cal=" + event.EventCalendarCid + ")\n\n")
	}

	// Injected proposal/comment form (if provided)
	if a.CommentForm != nil {
		sb.WriteString(a.CommentForm(eventCid, event) + "\n")
	}

	return sb.String()
}

func (a *CalendarApp) renderEventCalendar(c EventCalendar) string {
	var sb strings.Builder
	sb.WriteString("### " + c.Title + "\n")
	sb.WriteString(c.Thumbnail() + "\n\n")
	sb.WriteString("| Date | Description |\n| ---- | ----------- |\n")
	c.Events.IterateByOffset(0, c.Events.Size(), func(_ string, value any) bool {
		evtCid := value.(string)
		if evtRec, ok := a.getRecord(evtCid); ok {
			if evt, ok := evtRec.Object.(Schedule); ok {
				sb.WriteString("| " + evt.StartDate[:10] + " | [" + evt.Description + "](" + evt.ToPath(evt) + ") |\n")
			}
		}
		return false
	})
	return sb.String()
}

func (a *CalendarApp) renderEventCalendarTable() string {
	if a.EventCalendarIndex.Size() == 0 {
		return "No EventCalendars registered."
	}
	var sb strings.Builder
	sb.WriteString(a.eventCalendar.Heading())
	a.EventCalendarIndex.IterateByOffset(0, a.EventCalendarIndex.Size(), func(_ string, value any) bool {
		cid := value.(string)
		if rec, ok := a.getRecord(cid); ok {
			if cal, isCalendar := rec.Object.(EventCalendar); isCalendar {
				sb.WriteString(a.eventCalendar.Row(cal))
			}
		}
		return false
	})
	return sb.String()
}

func (a *CalendarApp) renderObject(rec eve.Record, lg eve.LogoGraph, projected interface{}) string {
	ld := lg.JsonLD()
	var sb strings.Builder

	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString(lg.Thumbnail() + "\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")

	sb.WriteString("**CID:** ")
	cid := ld.Cid()

	// If derived from a projectable view, offer commit if not yet stored.
	if projBase, isProj := rec.Object.(eve.Projectable); isProj && projected != nil {
		if _, found := a.objectStore.Get(cid); !found {
			sb.WriteString(cid + "\n\n")
			sb.WriteString(eve.Button(
				"Commit Projection:    "+eve.Tail(cid, 8),
				projBase.ToPath(projected)+"&base="+rec.Cid+"&submit=register"+"\n",
			))
		} else {
			sb.WriteString("[" + cid + "](" + projBase.ToPath(projected) + ")\n")
		}
	} else {
		sb.WriteString("[" + cid + "](?cid=" + cid + ")\n")
	}

	if links := ld.MarkdownLinks(); links != "" {
		sb.WriteString("\n### Links\n" + links + "\n")
	}
	sb.WriteString("\n#### JSON-LD\n```json\n" + strings.TrimSpace(ld.String()) + "\n```\n")
	return sb.String()
}

// -----------------------------------------------------------------------------
// Default/fallback forms (can be overridden via options)
// -----------------------------------------------------------------------------

func defaultCommentForm(cid string, event Schedule) string {
	if time.Now().After(ParseTimeSafe(event.EndDate).Add(48 * time.Hour)) {
		return ""
	}
	var sb strings.Builder
	sb.WriteString(`### Post a Message
<gno-columns>
<gno-form>
    <gno-textarea name="description" label="Description" rows="3" required placeholder="Post a message about this event."/>
    <gno-input name="topic" type="radio" value="` + cid + `" checked="true" />
    </gno-form>

|||

</gno-columns>
`)
	return sb.String()
}

// -----------------------------------------------------------------------------
// Time helpers
// -----------------------------------------------------------------------------

func ParseTimeSafe(timeStr string) time.Time {
	t, err := time.Parse(time.RFC3339, timeStr)
	if err != nil {
		return time.Time{}
	}
	return t
}

// -----------------------------------------------------------------------------
// Schedule (LogoGraph + Projectable)
// -----------------------------------------------------------------------------

var _ eve.LogoGraph = (*Schedule)(nil)
var _ eve.Projectable = (*Schedule)(nil)

func ScheduleFromEvent(evt *Event, cid string) Schedule {
    return Schedule{
        Status:           string(evt.Status),
        StartDate:        evt.StartDate.Format(time.RFC3339),
        EndDate:          evt.EndDate.Format(time.RFC3339),
        Title:            evt.Name,
        Description:      evt.Description,
        EventCalendarCid: cid,
    }
}

type Schedule struct {
	Status           string
	StartDate        string
	EndDate          string
	Title            string
	Description      string
	EventCalendarCid string
}

func (o Schedule) Cid() string       { return o.JsonLD().Cid() }
func (o Schedule) Thumbnail() string { return "![" + o.Title + "](" + o.DataUrl() + ")" }
func (o Schedule) DataUrl() string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(o.SVG())
}
func (o Schedule) SVG() string { return scheduleSVG(o.Title) }
func (o Schedule) String() string {
	return "Schedule{Status:" + o.Status + ", StartDate:" + o.StartDate + "}"
}
func (o Schedule) JsonLD() eve.JsonLDMap {
	start, end, status, descr, title := parseOhrScheduleOpts(o)
	refURL := ""
	if o.EventCalendarCid != "" {
		refURL += "?cal=" + o.EventCalendarCid
	}
	return eve.JsonLDMap{
		"@context":             "https://schema.org",
		"@type":                "Event",
		"name":                 title,
		"description":          descr,
		"url":                  refURL,
		"eventStatus":          status,
		"startDate":            start,
		"endDate":              end,
		"representativeOfPage": true,
	}
}

// ToPath/FromPath/Compose all use the receiver as the *base/default*.
func (o Schedule) ToPath(obj interface{}) string {
	return "?" + scheduleToValues(coalesceScheduleWithBase(o, obj)).Encode()
}

// TODO: support time zones in the query params
func (o Schedule) FromPath(path string) interface{} {
	q := eve.ParseQuery(path)
	s := o
	if v := q.Get("status"); v != "" {
		s.Status = v
	}
	if v := q.Get("startDate"); v != "" {
		s.StartDate = v
	}
	if v := q.Get("endDate"); v != "" {
		s.EndDate = v
	}
	if v := q.Get("title"); v != "" {
		s.Title = v
	}
	if v := q.Get("description"); v != "" {
		s.Description = v
	}
	if v := q.Get("cal"); v != "" {
		s.EventCalendarCid = v
	}
	return s
}

func (o Schedule) Compose(obj interface{}) eve.LogoGraph {
	return coalesceScheduleWithBase(o, obj)
}

func coalesceScheduleWithBase(o Schedule, obj interface{}) Schedule {
	merged := o
	switch v := obj.(type) {
	case Schedule:
		if v.Status != "" {
			merged.Status = v.Status
		}
		if v.StartDate != "" {
			merged.StartDate = v.StartDate
		}
		if v.EndDate != "" {
			merged.EndDate = v.EndDate
		}
		if v.Title != "" {
			merged.Title = v.Title
		}
		if v.Description != "" {
			merged.Description = v.Description
		}
		if v.EventCalendarCid != "" {
			merged.EventCalendarCid = v.EventCalendarCid
		}
	}
	return merged
}

func scheduleToValues(s Schedule) url.Values {
	q := url.Values{}
	q.Set("cid", s.Cid())
	if s.Status != "" {
		q.Set("status", s.Status)
	}
	if s.StartDate != "" {
		q.Set("startDate", s.StartDate)
	}
	if s.EndDate != "" {
		q.Set("endDate", s.EndDate)
	}
	if s.Title != "" {
		q.Set("title", s.Title)
	}
	if s.Description != "" {
		q.Set("description", s.Description)
	}
	if s.EventCalendarCid != "" {
		q.Set("cal", s.EventCalendarCid)
	}
	return q
}

func parseOhrScheduleOpts(obj Schedule) (start, end time.Time, status, descr, title string) {
	start, _ = time.Parse(time.RFC3339, obj.StartDate)
	end, _ = time.Parse(time.RFC3339, obj.EndDate)
	if end.IsZero() || !end.After(start) {
		end = start
	}
	status = obj.Status
	descr = obj.Description
	if descr == "" {
		descr = "AibLabs Event EventCalendar: Join us for open discussion."
	}
	title = obj.Title
	return
}

func scheduleSVG(title string) string {
	if title == "" {
		title = "Event EventCalendar"
	}
	return `
<svg width="250" height="200" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <text x="100" y="120" text-anchor="middle" font-size="94" font-weight="bold" fill="#E63946">🗓</text>
  <text x="100" y="170" text-anchor="middle" font-size="22" font-weight="bold" fill="#222">` + title + `</text>
</svg>`
}

// -----------------------------------------------------------------------------
// EventCalendar (LogoGraph)
// -----------------------------------------------------------------------------

type EventCalendar struct {
	Title   string
	Events  *avl.Tree // key: event CID, value: event CID (string)
	Default Schedule  // visualize/forward via this schedule
}

var _ eve.LogoGraph = (*EventCalendar)(nil)

// Build a Schedule from the EventCalendar (using the EventCalendar's Default as base).
func (c EventCalendar) Event(EventCalendarCid string, path ...string) Schedule {
	base := c.Default
	var s Schedule
	if len(path) > 0 && path[0] != "" {
		if ss, ok := base.FromPath(path[0]).(Schedule); ok {
			s = ss
		} else {
			s = base
		}
	} else {
		s = base
	}
	// Preserve base status (like previous behavior)
	s.Status = base.Status
	s.EventCalendarCid = EventCalendarCid
	return s
}

// LogoGraph forwards to the EventCalendar's Default schedule visuals.
func (c EventCalendar) Cid() string           { return c.Default.JsonLD().Cid() }
func (c EventCalendar) Thumbnail() string     { return c.Default.Thumbnail() }
func (c EventCalendar) SVG() string           { return c.Default.SVG() }
func (c EventCalendar) JsonLD() eve.JsonLDMap { return c.Default.JsonLD() }

func (EventCalendar) Heading() string { return "|          |\n| -------- |\n" }
func (EventCalendar) Row(obj EventCalendar) string {
	cidLink := "?cal=" + obj.Cid()
	return "| [" + obj.Thumbnail() + "](" + cidLink + ") |\n" +
	"| 📅 ["+ obj.Title + " Calendar](" + cidLink + ")" + " |\n" +
	"| 📄 [View Event Flyer]("+ cidLink +"&render=flyer)" + " |\n"
}
