package officehours

import (
	"net/url"
	"std"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	eve "gno.land/p/eve000/event/component"
)

/*
App holds *all* mutable module state.
Expose App.Render(path) (and other methods) on this wrapper object.
*/
type App struct {
	// Storage (single source of truth)
	objectStore   *avl.Tree // key: cid -> value: eve.Record
	// Lightweight indices (CIDs only)
	calendarIndex *avl.Tree // key: cid -> value: cid
	eventIndex    *avl.Tree // key: cid -> value: cid

	// Sequencing
	counter eve.Counter

	// Validation config
	requiredLDCols []string

	// Defaults / seeds
	defaultSchedule Schedule
	eventCalendar   calendar
	defaultEventCid string
}

// Only one module-level var:
var app = New()

// Render routes through the singleton App.
func Render(path string) string { return app.Render(path) }

// New builds a fresh App and seeds the calendar + one event.
func New() *App {
	a := &App{
		objectStore:    avl.NewTree(),
		calendarIndex:  avl.NewTree(),
		eventIndex:     avl.NewTree(),
		requiredLDCols: []string{"name", "description"},
		defaultSchedule: Schedule{
			Status:      "EventScheduled",
			StartDate:   "2025-11-01T10:20:00Z",
			EndDate:     "2025-11-01T11:20:00Z",
			Title:       "AibLabs Office Hours",
			Description: "AibLabs Office Hours: Join us for open discussion.",
		},
	}

	// Seed a calendar that carries its own default schedule.
	a.eventCalendar = calendar{
		Title:   "AibLabs.net Calendar",
		Events:  avl.NewTree(),
		Default: a.defaultSchedule,
	}

	// Register calendar and one example event, and index them.
	a.Register(a.eventCalendar, func(rec eve.Record) {
		cal := rec.Object.(calendar)

		evtCid := a.Register(cal.Event(rec.Cid))
		a.defaultEventCid = evtCid

		// Calendar tracks only the event CID (no duplication of Schedule).
		cal.Events.Set(evtCid, evtCid)

		// Persist the updated calendar back into the store.
		a.objectStore.Set(rec.Cid, eve.Record{
			Name:        rec.Name,
			Description: rec.Description,
			Cid:         rec.Cid,
			Object:      cal,
			Committer:   rec.Committer,
			Seq:         rec.Seq,
		})
	})

	return a
}

// -----------------------------------------------------------------------------
// Small helpers (now methods on *App)
// -----------------------------------------------------------------------------

func (a *App) seqNext() (n int64, s string) {
	n = a.counter.Bump()
	return n, ufmt.Sprintf("%08d", n)
}

func (a *App) getRecord(cid string) (eve.Record, bool) {
	if v, ok := a.objectStore.Get(cid); ok {
		if r, ok2 := v.(eve.Record); ok2 {
			return r, true
		}
	}
	return eve.Record{}, false
}

// -----------------------------------------------------------------------------
// Projection plumbing (methods)
// -----------------------------------------------------------------------------

// EmitProjectionEvent validates + emits, but does not register the projection.
func (a *App) EmitProjectionEvent(base, path, seal string) (string, error) {
	return a.commitProjection(true, base, path, seal)
}

// CommitProjection validates + registers a projected object derived from base+path.
func (a *App) CommitProjection(base, path, seal string) (string, error) {
	return a.commitProjection(false, base, path, seal)
}

func (a *App) commitProjection(emitOnly bool, base, path, seal string) (cid string, err error) {
	eve.MustCIDv1("seal", seal)
	eve.MustCIDv1("base", base)

	parent, ok := a.getRecord(base)
	if !ok {
		panic("base CID not found")
	}
	proj, ok := parent.Object.(eve.Projectable)
	if !ok {
		panic("object is not projectable")
	}

	projected := proj.FromPath(path)
	lg := proj.Compose(projected)
	cid = lg.JsonLD().Cid()
	if seal != cid {
		panic("invalid seal: expected " + cid + " but got " + seal)
	}

	// Panic if already present.
	if _, exists := a.objectStore.Get(cid); exists {
		panic("projection already exists: " + cid)
	}

	if !emitOnly {
		seq, seqStr := a.seqNext()
		rec := eve.Record{
			Name:        parent.Name + " (projected)",
			Description: parent.Description + " (projected)",
			Cid:         cid,
			Object:      projected,
			Committer:   std.PreviousRealm().Address().String(),
			Seq:         seq,
		}
		a.objectStore.Set(rec.Cid, rec)

		// Index by kind.
		switch projected.(type) {
		case calendar:
			a.calendarIndex.Set(rec.Cid, rec.Cid)
		case Schedule:
			a.eventIndex.Set(rec.Cid, rec.Cid)
		}

		std.Emit("ProjectionCommitted", "cid", cid, "seal", seal, "seq", seqStr)
	}

	// Always emit the event
	_, seqStr := a.seqNext()
	std.Emit("ProjectionEvent", "cid", cid, "seal", seal, "seq", seqStr)

	return cid, nil
}

// -----------------------------------------------------------------------------
// Register (method)
// -----------------------------------------------------------------------------

// Register adds a LogoGraph object to the store and indexes it by type.
func (a *App) Register(obj interface{}, cb ...func(rec eve.Record)) string {
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

	// Index by kind (CIDs only).
	switch obj.(type) {
	case calendar:
		a.calendarIndex.Set(rec.Cid, rec.Cid)
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

func (a *App) Render(path string) string {
	q := eve.ParseQuery(path)

	// Object route: ?cal=<calendarCid>&cid=<objectCid>
	if cal, hasCal := q["cal"]; hasCal && len(cal) == 1 {
		if cid, hasCid := q["cid"]; hasCid && len(cid) == 1 {
			rec, ok := a.getRecord(cid[0])
			if !ok {
				// TODO: build-from-URL fallback
				return "cid not found"
			}
			lg, projected, ok := eve.AsLogoGraph(rec.Object, path)
			if !ok {
				return "object is not renderable (no eve.LogoGraph)"
			}
			return a.renderObject(rec, lg, projected)
		}
	}

	// Calendar route: ?cal=<calendarCid>[&evt=<eventCid>]
	if cal, hasCal := q["cal"]; hasCal && len(cal) == 1 {
		if rec, ok := a.getRecord(cal[0]); ok {
			if c, ok := rec.Object.(calendar); ok {
				if event, hasEvt := q["evt"]; hasEvt && len(event) == 1 {
					if _, ok := c.Events.Get(event[0]); ok {
						if evtRec, ok := a.getRecord(event[0]); ok {
							return renderEvent(evtRec.Object)
						}
						return "event (cid) not found in object store: " + event[0]
					}
					return "event cid not found in calendar: " + event[0]
				}
				return a.renderCalendar(c)
			}
			return "invalid calendar record"
		}
		return "cal cid not found: " + cal[0]
	}

	// Global routes
	if _, hasCid := q["cid"]; !hasCid {
		if v, ok := q["v"]; ok && len(v) == 1 && v[0] == "seq" {
			return a.counter.String()
		}
		return a.renderCalendarTable()
	}

	// Optional: projection registration form
	if submit, ok := q["submit"]; ok && len(submit) > 0 && submit[0] == "register" {
		if base, ok := q["base"]; ok && len(base) > 0 && eve.IsCIDv1(base[0]) {
			if r, ok := a.getRecord(base[0]); ok {
				if ed, isEd := r.Object.(eve.Editable); isEd {
					if form := ed.RenderForm(path); form != "" {
						return form
					}
				}
			} else {
				return "base cid not found: " + base[0]
			}
		} else {
			return "missing or invalid base parameter"
		}
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

func renderEvent(obj interface{}) string {
	event, ok := obj.(Schedule)
	if !ok {
		return "object is not a scheduled event"
	}
	eventCid := event.Cid()

	var sb strings.Builder
	sb.WriteString("### " + event.Title + "\n")
	sb.WriteString(event.Thumbnail() + "\n\n")
	sb.WriteString(event.Description + "\n\n")

	sb.WriteString("**CID:** [" + eventCid[len(eventCid)-8:] + "](?cid=" + eventCid + "&cal=" + event.CalendarCid + ")\n\n")
	sb.WriteString("**Status:** " + event.Status + "\n\n")
	sb.WriteString("**Date:** " + event.StartDate[:10] + "\n\n")
	sb.WriteString("**Time:** " + event.StartDate[11:16] + " to " + event.EndDate[11:16] + " UTC\n\n")
	if event.CalendarCid != "" {
		sb.WriteString("[← Calendar" + "](?cal=" + event.CalendarCid + ")\n\n")
	}
	sb.WriteString(proposalForm(eventCid, event) + "\n")
	return sb.String()
}

func (a *App) renderCalendar(c calendar) string {
	var sb strings.Builder
	sb.WriteString("### " + c.Title + "\n")
	sb.WriteString(c.Thumbnail() + "\n\n")
	sb.WriteString("| Date | Description |\n| ---- | ----------- |\n")
	c.Events.IterateByOffset(0, c.Events.Size(), func(_ string, value any) bool {
		evtCid := value.(string)
		if evtRec, ok := a.getRecord(evtCid); ok {
			if evt, ok := evtRec.Object.(Schedule); ok {
				sb.WriteString("| " + evt.StartDate[:10] + " | [" + evt.Description + "](?evt=" + evtCid + "&cal=" + c.Cid() + ") |\n")
			}
		}
		return false
	})
	return sb.String()
}

func (a *App) renderCalendarTable() string {
	if a.calendarIndex.Size() == 0 {
		return "No calendars registered."
	}
	var sb strings.Builder
	sb.WriteString(a.eventCalendar.Heading())
	a.calendarIndex.IterateByOffset(0, a.calendarIndex.Size(), func(_ string, value any) bool {
		cid := value.(string)
		if rec, ok := a.getRecord(cid); ok {
			if cal, isCalendar := rec.Object.(calendar); isCalendar {
				sb.WriteString(a.eventCalendar.Row(cal))
			}
		}
		return false
	})
	return sb.String()
}

func (a *App) renderObject(rec eve.Record, lg eve.LogoGraph, projected interface{}) string {
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
			sb.WriteString(eve.Button("Commit Projection:    "+eve.Tail(cid, 8),
				projBase.ToPath(projected)+"&base="+rec.Cid+"&submit=register"+"\n"))
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

func parseTimeSafe(timeStr string) time.Time {
	t, err := time.Parse(time.RFC3339, timeStr)
	if err != nil {
		return time.Time{}
	}
	return t
}

func proposalForm(cid string, event Schedule) string {
	if time.Now().After(parseTimeSafe(event.EndDate).Add(48 * time.Hour)) {
		return ""
	}
	var sb strings.Builder
	sb.WriteString(`### Propose Topic
<gno-columns>
<gno-form>
    <gno-textarea name="description" label="Description" rows="3" required placeholder="Describe your topic proposal, Or leave a comment here..."/>
    <gno-input name="topic" type="radio" value="` + cid + `" checked="true" description="Submit for this Session" />
    </gno-form>

|||

</gno-columns>
`)
	return sb.String()
}

// -----------------------------------------------------------------------------
// Schedule (LogoGraph + Projectable), SELF-DEFAULTING via receiver
// -----------------------------------------------------------------------------

type Schedule struct {
	Status      string
	StartDate   string
	EndDate     string
	Title       string
	Description string
	CalendarCid string
}

func (o Schedule) Cid() string       { return o.JsonLD().Cid() }
func (o Schedule) Thumbnail() string { return "![OhrSchedule](" + o.DataUrl() + ")" }
func (o Schedule) DataUrl() string   { return "data:image/svg+xml;charset=utf-8," + url.PathEscape(o.SVG()) }
func (Schedule) SVG() string         { return scheduleSVG }
func (o Schedule) String() string    { return "Schedule{Status:" + o.Status + ", StartDate:" + o.StartDate + "}" }
func (o Schedule) JsonLD() eve.JsonLDMap {
	start, end, status, descr, title := parseOhrScheduleOpts(o)
	refURL := ""
	if o.CalendarCid != "" {
		refURL += "?cal=" + o.CalendarCid
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
func (base Schedule) ToPath(obj interface{}) string {
	return "?" + scheduleToValues(coalesceScheduleWithBase(base, obj)).Encode()
}

// TODO: support time zones in the query params
func (base Schedule) FromPath(path string) interface{} {
	q := eve.ParseQuery(path)
	s := base
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
		s.CalendarCid = v
	}
	return s
}

func (base Schedule) Compose(obj interface{}) eve.LogoGraph {
	return coalesceScheduleWithBase(base, obj)
}

func coalesceScheduleWithBase(base Schedule, obj interface{}) Schedule {
	merged := base
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
		if v.CalendarCid != "" {
			merged.CalendarCid = v.CalendarCid
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
	if s.CalendarCid != "" {
		q.Set("cal", s.CalendarCid)
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
		descr = "AibLabs Event Calendar: Join us for open discussion."
	}
	title = obj.Title
	return
}

const scheduleSVG = `
<svg width="300" height="200" viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="20" width="260" height="160" rx="18" ry="18" fill="#fff" stroke="#bbb" stroke-width="3" />
  <g transform="translate(150,90)">
    <circle cx="0" cy="0" r="48" fill="#fff" stroke="#222" stroke-width="4"/>
    <line x1="0" y1="0" x2="-32" y2="-26" stroke="#222" stroke-width="6" stroke-linecap="round"/>
    <line x1="0" y1="0" x2="32" y2="16" stroke="#222" stroke-width="4" stroke-linecap="round"/>
    <circle cx="0" cy="0" r="6" fill="#222"/>
  </g>
  <text x="150" y="170" text-anchor="middle" font-size="32" font-weight="bold" fill="#222">Office Hours</text>
</svg>`

// -----------------------------------------------------------------------------
// calendar (LogoGraph + Projectable passthrough)
// -----------------------------------------------------------------------------

type calendar struct {
	Title   string
	Events  *avl.Tree // key: event CID, value: event CID (string)
	Default Schedule  // visualize/forward via this schedule
}

var _ eve.LogoGraph = calendar{}

// Build a Schedule from the calendar (using the calendar's Default as base).
func (c calendar) Event(calendarCid string, path ...string) Schedule {
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
	s.CalendarCid = calendarCid
	return s
}

// LogoGraph forwards to the calendar's Default schedule visuals.
func (c calendar) Cid() string           { return c.Default.JsonLD().Cid() }
func (c calendar) Thumbnail() string     { return c.Default.Thumbnail() }
func (c calendar) SVG() string           { return c.Default.SVG() }
func (c calendar) JsonLD() eve.JsonLDMap { return c.Default.JsonLD() }

func (calendar) Heading() string { return "|          |\n| -------- |\n" }
func (calendar) Row(obj calendar) string {
	return "| [" + obj.Thumbnail() + obj.Title + "](./officehours?cal=" + obj.Cid() + ") | "
}
