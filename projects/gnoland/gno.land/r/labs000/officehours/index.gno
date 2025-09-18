package officehours

// -----------------------------------------------------------------------------
// This system is an instance of applied categorical programming: interfaces implement
// categorical structure (objects, morphisms, functors), runtime checks enforce
// laws (identity, composition, naturality),
// and registries serve as skeletal categories with presheaf indices.
//
// Projection commits are pushouts; calendar–event membership is a span;
// rendering is a natural transformation.
//
// The result is a falsifiable, compositional substrate for on-chain objects.
// -----------------------------------------------------------------------------
//

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
// Registries & sequencing
// -----------------------------------------------------------------------------

// Single source of truth for all objects (stored once).
var objectStore = avl.NewTree() // key: cid -> value: Record

// Lightweight indices (store only CIDs).
var calendarIndex = avl.NewTree() // key: cid -> value: cid
var eventIndex = avl.NewTree()    // key: cid -> value: cid

type Counter struct{ Count int64 }

func (c *Counter) bump() int64    { c.Count++; return c.Count }
func (c *Counter) String() string { return ufmt.Sprintf("%08d", c.Count) }

var counter = Counter{}

// -----------------------------------------------------------------------------
// Interfaces
// -----------------------------------------------------------------------------

type Editable interface {
	RenderForm(path string) string
}

type Projectable interface {
	ToPath(obj interface{}) string
	FromPath(path string) interface{}
	// Compose must return a value that implements LogoGraph.
	Compose(obj interface{}) LogoGraph
}

type LogoGraph interface {
	SVG() string
	JsonLD() eve.JsonLDMap
	Cid() string
	Thumbnail() string
}

// -----------------------------------------------------------------------------
// Records
// -----------------------------------------------------------------------------

type Record struct {
	Name        string
	Description string
	Cid         string
	Object      interface{}
	Committer   string
	Seq         int64
}

var requiredLDCols = []string{"name", "description"} // cid/committer derived, not required in JSON-LD

// tail returns the last n characters of s (or the whole string if shorter).
func tail(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[len(s)-n:]
}

func (e Record) String() string {
	return "| [" + tail(e.Cid, 8) + "](?cid=" + e.Cid + ") | " +
		e.Name + " | " + e.Description + " | " +
		"[" + tail(e.Committer, 8) + "](/u/" + e.Committer + ") |\n"
}

// -----------------------------------------------------------------------------
// Small helpers
// -----------------------------------------------------------------------------

func mustCIDv1(label, s string) {
	if !eve.IsCIDv1(s) {
		panic("invalid " + label + ": not a CIDv1")
	}
}

func seqNext() (n int64, s string) {
	n = counter.bump()
	return n, ufmt.Sprintf("%08d", n)
}

func getRecord(cid string) (Record, bool) {
	if v, ok := objectStore.Get(cid); ok {
		if r, ok2 := v.(Record); ok2 {
			return r, true
		}
	}
	return Record{}, false
}

// Resolve an arbitrary object (possibly projectable) into a LogoGraph view.
func asLogoGraph(baseObj interface{}, path string) (lg LogoGraph, projected interface{}, ok bool) {
	switch v := baseObj.(type) {
	case Projectable:
		projected = v.FromPath(path)
		return v.Compose(projected), projected, true
	case LogoGraph:
		return v, v, true
	default:
		return nil, nil, false
	}
}

// -----------------------------------------------------------------------------
// Projection plumbing
// -----------------------------------------------------------------------------

// EmitProjectionEvent validates + emits, but does not register the projection.
func EmitProjectionEvent(base, path, seal string) (string, error) { return commitProjection(true, base, path, seal) }

// CommitProjection validates + registers a projected object derived from base+path.
func CommitProjection(base, path, seal string) (string, error) { return commitProjection(false, base, path, seal) }

func commitProjection(emitOnly bool, base, path, seal string) (cid string, err error) {
	mustCIDv1("seal", seal)
	mustCIDv1("base", base)

	parent, ok := getRecord(base)
	if !ok {
		panic("base CID not found")
	}
	proj, ok := parent.Object.(Projectable)
	if !ok {
		panic("object is not projectable")
	}

	projected := proj.FromPath(path)
	lg := proj.Compose(projected)
	cid = lg.JsonLD().Cid()
	if seal != cid {
		panic("invalid seal: expected " + cid + " but got " + seal)
	}

	// Only store if not already present.
	if _, exists := objectStore.Get(cid); !exists && !emitOnly {
		seq, seqStr := seqNext()
		rec := Record{
			Name:        parent.Name + " (projected)",
			Description: parent.Description + " (projected)",
			Cid:         cid,
			Object:      projected,
			Committer:   std.PreviousRealm().Address().String(),
			Seq:         seq,
		}
		objectStore.Set(rec.Cid, rec)

		// Index by kind.
		switch projected.(type) {
		case calendar:
			calendarIndex.Set(rec.Cid, rec.Cid)
		case Schedule:
			eventIndex.Set(rec.Cid, rec.Cid)
		}

		std.Emit("ProjectionCommitted", "cid", cid, "seal", seal, "seq", seqStr)
	}

	// Always emit the event
	_, seqStr := seqNext()
	std.Emit("ProjectionEvent", "cid", cid, "seal", seal, "seq", seqStr)

	return cid, nil
}

// -----------------------------------------------------------------------------
// Register
// -----------------------------------------------------------------------------

// Register adds a LogoGraph object to the object store and indexes it by type.
func Register(obj interface{}, cb ...func(rec Record)) string {
	lg, ok := obj.(LogoGraph)
	if !ok {
		panic("object must implement LogoGraph interface")
	}

	newCid := lg.Cid()
	mustCIDv1("object CID", newCid)

	// Smoke-test media
	_ = lg.SVG()
	_ = lg.Thumbnail()

	ld := lg.JsonLD()
	for _, col := range requiredLDCols {
		if _, ok := ld[col]; !ok {
			panic("object JSON-LD must include " + col)
		}
	}

	if _, exists := objectStore.Get(newCid); exists {
		panic("duplicate CID registered: " + newCid)
	}

	seq, seqStr := seqNext()
	rec := Record{
		Name:        ld.StringVal("name"),
		Description: ld.StringVal("description"),
		Cid:         newCid,
		Object:      obj,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         seq,
	}

	// Store exactly once.
	objectStore.Set(rec.Cid, rec)
	std.Emit("Register", "cid", rec.Cid, "seq", seqStr)

	// Index by kind (CIDs only).
	switch obj.(type) {
	case calendar:
		calendarIndex.Set(rec.Cid, rec.Cid)
	case Schedule:
		eventIndex.Set(rec.Cid, rec.Cid)
	}

	for _, f := range cb {
		f(rec)
	}
	return newCid
}

// -----------------------------------------------------------------------------
// Render router
// -----------------------------------------------------------------------------

func Render(path string) string {
	q := eve.ParseQuery(path)

	// Calendar route: ?cal=<calendarCid>[&evt=<eventCid>]
	if cal, hasCal := q["cal"]; hasCal && len(cal) == 1 {
		if rec, ok := getRecord(cal[0]); ok {
			if c, ok := rec.Object.(calendar); ok {
				if event, hasEvt := q["evt"]; hasEvt && len(event) == 1 {
					if _, ok := c.Events.Get(event[0]); ok {
						if evtRec, ok := getRecord(event[0]); ok {
							return renderEvent(evtRec.Object)
						}
						return "event (cid) not found in object store: " + event[0]
					}
					return "event cid not found in calendar: " + event[0]
				}
				return renderCalendar(c)
			}
			return "invalid calendar record"
		}
		return "cal cid not found: " + cal[0]
	}

	// Global routes
	if _, hasCid := q["cid"]; !hasCid {
		if v, ok := q["v"]; ok && len(v) == 1 && v[0] == "seq" {
			return counter.String()
		}
		return eventCalendar.RenderTable()
	}

	// Optional: projection registration form
	if submit, ok := q["submit"]; ok && len(submit) > 0 && submit[0] == "register" {
		if base, ok := q["base"]; ok && len(base) > 0 && eve.IsCIDv1(base[0]) {
			if r, ok := getRecord(base[0]); ok {
				if ed, isEd := r.Object.(Editable); isEd {
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
	rec, ok := getRecord(cid)
	if !ok {
		return "cid not found"
	}

	lg, projected, ok := asLogoGraph(rec.Object, path)
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
		mustCIDv1("seal", seal[0])
		calc := lg.JsonLD().Cid()
		if seal[0] != calc {
			return "invalid seal: expected " + calc + " but got " + seal[0]
		}
	}

	return renderObject(rec, lg, projected)
}

// -----------------------------------------------------------------------------
// Render helpers
// -----------------------------------------------------------------------------

func renderEvent(obj interface{}) string {
	event, ok := obj.(Schedule)
	if !ok {
		return "object is not a scheduled event"
	}

	var sb strings.Builder
	sb.WriteString("### " + event.Title + "\n")
	sb.WriteString(event.Thumbnail() + "\n\n")
	sb.WriteString(event.Description + "\n\n")
	sb.WriteString("[" + event.Cid() + "](?evt=" + event.Cid() + "&cal=" + event.CalendarCid + ")\n\n")
	sb.WriteString("**Status:** " + event.Status + "\n\n")
	sb.WriteString("**Date:** " + event.StartDate[:10] + "\n\n")
	sb.WriteString("**Location:** " + event.Location + "\n\n")
	sb.WriteString("#### JSON-LD\n```json\n" + strings.TrimSpace(event.JsonLD().String()) + "\n```\n")
	return sb.String()
}

func renderCalendar(c calendar) string {
	var sb strings.Builder
	sb.WriteString("### " + c.Title + "\n")
	sb.WriteString(c.Thumbnail() + "\n\n")
	sb.WriteString("| Date | Description |\n| ---- | ----------- |\n")
	c.Events.IterateByOffset(0, c.Events.Size(), func(_ string, value any) bool {
		evtCid := value.(string)
		if evtRec, ok := getRecord(evtCid); ok {
			if evt, ok := evtRec.Object.(Schedule); ok {
				sb.WriteString("| " + evt.StartDate[:10] + " | [" + evt.Description + "](?evt=" + evtCid + "&cal=" + c.Cid() + ") |\n")
			}
		}
		return false
	})
	return sb.String()
}

func renderObject(rec Record, lg LogoGraph, projected interface{}) string {
	ld := lg.JsonLD()
	var sb strings.Builder

	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString(lg.Thumbnail() + "\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")

	sb.WriteString("#### CID\n")
	cid := ld.Cid()

	// If render derived from a projectable view, offer commit button if not yet stored.
	if projBase, isProj := rec.Object.(Projectable); isProj && projected != nil {
		if _, found := objectStore.Get(cid); !found {
			sb.WriteString(cid + "\n\n")
			sb.WriteString(eve.Button("Commit Projection:    "+tail(cid, 8),
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

// -----------------------------------------------------------------------------
// Schedule (LogoGraph + Projectable)
// -----------------------------------------------------------------------------

type Schedule struct {
	Status      string
	StartDate   string
	EndDate     string
	Location    string
	Title       string
	Description string
	CalendarCid string
}

func (o Schedule) Cid() string                 { return o.JsonLD().Cid() }
func (o Schedule) Thumbnail() string           { return "![OhrSchedule](" + o.DataUrl() + ")" }
func (o Schedule) DataUrl() string             { return "data:image/svg+xml;charset=utf-8," + url.PathEscape(o.SVG()) }
func (Schedule) SVG() string                   { return scheduleSVG }
func (o Schedule) String() string              { return "Schedule{Status:" + o.Status + ", StartDate:" + o.StartDate + "}" }
func (o Schedule) JsonLD() eve.JsonLDMap       { return scheduleLD(o) }
func (Schedule) ToPath(obj interface{}) string { return "?" + scheduleToValues(coalesceSchedule(obj)).Encode() }
func (Schedule) FromPath(path string) interface{} {
	q := eve.ParseQuery(path)
	s := defaultSchedule
	if v := q.Get("status"); v != "" {
		s.Status = v
	}
	if v := q.Get("startDate"); v != "" {
		s.StartDate = v
	}
	if v := q.Get("endDate"); v != "" {
		s.EndDate = v
	}
	if v := q.Get("location"); v != "" {
		s.Location = v
	}
	if v := q.Get("title"); v != "" {
		s.Title = v
	}
	if v := q.Get("description"); v != "" {
		s.Description = v
	}
	return s
}
func (Schedule) Compose(obj interface{}) LogoGraph { return coalesceSchedule(obj) }

var defaultSchedule = Schedule{
	Status:      "EventScheduled",
	StartDate:   "2025-01-01T10:20:00Z",
	EndDate:     "2025-01-01T11:20:00Z",
	Location:    "Online",
	Title:       "AibLabs Office Hours",
	Description: "AibLabs Event Calendar: Join us for open discussion.",
}

func coalesceSchedule(obj interface{}) Schedule {
	merged := defaultSchedule
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
		if v.Location != "" {
			merged.Location = v.Location
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

func scheduleLD(s Schedule) eve.JsonLDMap {
	start, end, status, location, descr := parseOhrScheduleOpts(s)
	refURL := "/r/labs000/officehours"
	if s.CalendarCid != "" {
		refURL += "?cal=" + s.CalendarCid
	}
	return eve.JsonLDMap{
		"@context":             "https://schema.org",
		"@type":                "ImageObject",
		"name":                 "Calendar",
		"description":          descr,
		"url":                  "/r/labs000/officehours",
		"representativeOfPage": true,
		"partOf": map[string]interface{}{
			"@type": "WebPage",
			"name":  "AibLabs Office Hours",
			"url":   refURL,
		},
		"about": map[string]interface{}{
			"@type":       "Event",
			"name":        "AibLabs Office Hours",
			"description": descr,
			"eventStatus": status,
			"startDate":   start,
			"endDate":     end,
			"location": map[string]interface{}{
				"@type":   "Place",
				"name":    location,
				"address": location,
			},
		},
	}
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
	if s.Location != "" {
		q.Set("location", s.Location)
	}
	if s.Title != "" {
		q.Set("title", s.Title)
	}
	if s.Description != "" {
		q.Set("description", s.Description)
	}
	return q
}

func parseOhrScheduleOpts(obj Schedule) (start, end time.Time, status, location, descr string) {
	start, _ = time.Parse(time.RFC3339, obj.StartDate)
	end, _ = time.Parse(time.RFC3339, obj.EndDate)
	if end.IsZero() || !end.After(start) {
		end = start
	}
	status = obj.Status
	location = obj.Location
	if location == "" {
		location = "Online"
	}
	descr = obj.Description
	if descr == "" {
		descr = "AibLabs Event Calendar: Join us for open discussion."
	}
	return
}

const scheduleSVG = `
<svg width="300" height="200" viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="20" width="260" height="160" rx="18" ry="18" fill="#fff" stroke="#bbb" stroke-width="3" filter="url(#shadow)"/>
  <defs>
    <filter id="shadow" x="0" y="0" width="200%" height="200%">
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#888" flood-opacity="0.18"/>
    </filter>
  </defs>
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
	Title  string
	Events *avl.Tree // key: event CID, value: event CID (string)
}

var eventCalendar = calendar{
	Title:  "Gno.land Office Hours Calendar",
	Events: avl.NewTree(),
}

var _ LogoGraph = eventCalendar
var _ Projectable = eventCalendar

func init() {
	// Register the calendar and seed a single example event.
	Register(eventCalendar, func(rec Record) {
		cal := rec.Object.(calendar)

		// Create a planned event for this calendar and register it once.
		evt := cal.Event(rec.Cid)
		evtCid := Register(evt) // indexes into eventIndex; stored once in objectStore

		// Calendar tracks only the event CID (no duplication of Schedule).
		cal.Events.Set(evtCid, evtCid)

        // REVIEW would it be better to have a mutable calendar object??
		// Persist updated calendar back into objectStore under the same CID.
		objectStore.Set(rec.Cid, Record{
			Name:        rec.Name,
			Description: rec.Description,
			Cid:         rec.Cid,
			Object:      cal,
			Committer:   rec.Committer,
			Seq:         rec.Seq,
		})
	})
}

func (c calendar) Event(calendarCid string, path ...string) Schedule {
    // TODO: lookup event by path if given
	s := defaultSchedule
	s.Status = "EventPlanned"
	s.Location = "Gnowhere"
	s.CalendarCid = calendarCid
	return s
}

// LogoGraph forwards to schedule visuals (placeholder)
func (calendar) Cid() string           { return eventCalendar.JsonLD().Cid() }
func (calendar) Thumbnail() string     { return defaultSchedule.Thumbnail() }
func (calendar) SVG() string           { return defaultSchedule.SVG() }
func (calendar) JsonLD() eve.JsonLDMap { return defaultSchedule.JsonLD() }

// Projectable passthrough
func (calendar) FromPath(path string) interface{} { return defaultSchedule.FromPath(path) }
func (calendar) ToPath(obj interface{}) string    { return defaultSchedule.ToPath(obj) }
func (calendar) Compose(obj interface{}) LogoGraph {
	return coalesceSchedule(obj)
}

func (calendar) Heading() string { return "| Calendar |\n| -------- |\n" }
func (calendar) Row(obj calendar) string {
	return "| [" + obj.Title + "](./officehours?cal=" + obj.Cid() + ") | "
}
func (calendar) RenderTable() string {
	if calendarIndex.Size() == 0 {
		return "No calendars registered."
	}
	var sb strings.Builder
	sb.WriteString(eventCalendar.Heading())
	calendarIndex.IterateByOffset(0, calendarIndex.Size(), func(_ string, value any) bool {
		cid := value.(string)
		if rec, ok := getRecord(cid); ok {
			if cal, isCalendar := rec.Object.(calendar); isCalendar {
				sb.WriteString(eventCalendar.Row(cal))
			}
		}
		return false
	})
	return sb.String()
}
