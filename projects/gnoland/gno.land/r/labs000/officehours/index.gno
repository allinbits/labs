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

// -----------------------------------------------------------------------------
// Registry & sequencing
// -----------------------------------------------------------------------------

var calendarRegistry = avl.NewTree()

type Counter struct{ Count int64 }

// Bump increments and returns the new count.
func (c *Counter) Bump() int64 { c.Count++; return c.Count }

// Next returns the next sequence as zero-padded string (kept for compatibility).
func (c *Counter) Next() string { c.Bump(); return c.String() }

func (c *Counter) String() string { return ufmt.Sprintf("%08d", c.Count) }

var counter = Counter{Count: 0}

// -----------------------------------------------------------------------------
// Interfaces
// -----------------------------------------------------------------------------

type Editable interface {
	RenderForm(...string) string
}

type Projectable interface {
	ToPath(...interface{}) string
	FromPath(...string) interface{}
	// Compose MUST return a value that implements LogoGraph.
	Compose(...interface{}) LogoGraph
}

type LogoGraph interface {
	SVG(...string) string
	JsonLD(...string) eve.JsonLDMap
	Cid(...string) string
	Thumbnail(...string) string
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

var columns = []string{"cid", "name", "description", "committer"}

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
// Projection plumbing
// -----------------------------------------------------------------------------

// EmitProjectionEvent validates + emits, but does not register the projection.
func EmitProjectionEvent(base, path, seal string) (cid string, err error) {
	return commitProjection(true, base, path, seal)
}

// CommitProjection validates + registers a projected object derived from base+path.
func CommitProjection(base, path, seal string) (cid string, err error) {
	return commitProjection(false, base, path, seal)
}

func commitProjection(emitOnly bool, base, path, seal string) (cid string, err error) {
	if seal == "" {
		panic("seal parameter is required")
	}
	if !eve.IsCIDv1(base) {
		panic("invalid base: not a CIDv1")
	}
	if !eve.IsCIDv1(seal) {
		panic("invalid seal: not a CIDv1")
	}
	v, found := calendarRegistry.Get(base)
	if !found {
		panic("base CID not found")
	}
	r, ok := v.(Record)
	if !ok {
		panic("registry corruption: value is not a Record")
	}

	proj, isProj := r.Object.(Projectable)
	if !isProj {
		panic("object is not projectable")
	}

	// Build the projected object & compose to a LogoGraph
	projected := proj.FromPath(path)
	lg := proj.Compose(projected)
	cid = lg.JsonLD().Cid()

	if seal != cid {
		panic("invalid seal: expected " + cid + "but got" + seal)
	}
	if _, ok := calendarRegistry.Get(cid); ok {
		panic("duplicate projected CID registered: " + cid)
	}

	seq := counter.Bump()
	rec := Record{
		Name:        r.Name + " (projected)",
		Description: r.Description + " (projected)",
		Cid:         cid,
		Object:      projected,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         seq,
	}

	std.Emit("ProjectionEvent",
		"cid", cid,
		"seal", seal,
		"seq", ufmt.Sprintf("%08d", seq),
	)

	if !emitOnly {
		calendarRegistry.Set(rec.Cid, rec)
	}
	return cid, nil
}

// -----------------------------------------------------------------------------
// Register
// -----------------------------------------------------------------------------

// Register adds a LogoGraph object to the registry and returns its CID.
func Register(i interface{}, callback ...func(rec Record)) string {
	lg, ok := i.(LogoGraph)
	if !ok {
		panic("object must implement LogoGraph interface")
	}
	newCid := lg.Cid()
	if !eve.IsCIDv1(newCid) {
		panic("object must have a likely CIDv1 (base32, 'baf...' style)")
	}

	// Smoke-test media
	_ = lg.SVG()
	_ = lg.Thumbnail()

	ld := lg.JsonLD()

	// Optional: enforce columns if you want strictness
	for _, col := range columns {
		if col == "cid" || col == "committer" {
			continue
		}
		if _, ok := ld[col]; !ok {
			panic("object must have " + col + " in its JSON-LD")
		}
	}

	if _, ok := calendarRegistry.Get(newCid); ok {
		panic("duplicate CID registered: " + newCid)
	}

	seq := counter.Bump()
	rec := Record{
		Name:        ld.StringVal(columns[1]),
		Description: ld.StringVal(columns[2]),
		Cid:         newCid,
		Object:      i,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         seq,
	}

	calendarRegistry.Set(rec.Cid, rec)
	std.Emit("Register", "cid", rec.Cid, "seq", ufmt.Sprintf("%08d", seq))

	for _, cb := range callback {
		cb(rec)
	}
	return newCid
}

// -----------------------------------------------------------------------------
// Render router
// -----------------------------------------------------------------------------

func Render(path string) string {
	q := eve.ParseQuery(path)

	// Calendar route: ?cal=<calendarCid>[&evt=<eventCid>]
	if cal, hasCal := q["cal"]; hasCal {
		if calObj, ok := calendarRegistry.Get(cal[0]); ok {
			rec, ok := calObj.(Record)
			if !ok {
				return "invalid calendar record"
			}
			if c, ok := rec.Object.(calendar); ok {
				if event, hasEvent := q["evt"]; hasEvent {
					if evtObj, ok := c.Events.Get(event[0]); ok {
						return renderEvent(path, evtObj)
					}
					return "event cid not found: " + event[0]
				}
				return renderCalendar(path, rec.Object)
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
	if submit, hasSubmit := q["submit"]; hasSubmit && submit[0] == "register" {
		if base, hasBase := q["base"]; hasBase && eve.IsCIDv1(base[0]) {
			if v, ok := calendarRegistry.Get(base[0]); ok {
				r := v.(Record)
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
	v, found := calendarRegistry.Get(cid)
	if !found {
		return "cid not found"
	}

	r := v.(Record)
	baseCid := r.Cid

	obj := r.Object
	if proj, isProj := r.Object.(Projectable); isProj {
		obj = proj.FromPath(path) // may return a different instance (e.g., Schedule)
	}

	// Prepare a LogoGraph view (robustly, without panics)
	var lg LogoGraph
	if v, ok := obj.(LogoGraph); ok {
		lg = v
	} else if p, ok := r.Object.(Projectable); ok {
		lg = p.Compose(obj)
	} else {
		return "object is not renderable (no LogoGraph)"
	}

	// Structured views via v={ldjson|cid|seq|committer|svg|thumbnail|json}
	if format, ok := q["v"]; ok {
		switch format[0] {
		case "ldjson":
			ld := lg.JsonLD()
			if ldjson, ok := q["ldjson"]; ok && len(ldjson) > 0 {
				parts := strings.Split(ldjson[0], ".")
				val := interface{}(ld)
				for _, p := range parts {
					if m, ok := val.(eve.JsonLDMap); ok {
						val = m[p]
					} else {
						return ""
					}
				}
				switch v := val.(type) {
				case string:
					return v
				default:
					return ufmt.Sprintf("%v", v)
				}
			}
			return ld.String()

		case "cid":
			return "[" + lg.JsonLD().Cid() + "](?cid=" + lg.JsonLD().Cid() + ")"

		case "seq":
			return ufmt.Sprintf("%d", r.Seq)

		case "committer":
			return r.Committer

		case "svg":
			return lg.SVG()

		case "thumbnail":
			return lg.Thumbnail()

		case "json":
			return lg.JsonLD().String()
		}
	}

	// Optional seal verification
	if seal, ok := q["seal"]; ok && len(seal) > 0 {
		if !eve.IsCIDv1(seal[0]) {
			return "invalid seal: not a CIDv1"
		}
		calc := lg.JsonLD().Cid()
		if seal[0] != calc {
			return "invalid seal: expected " + calc + " but got " + seal[0]
		}
	}

	return renderObject(path, obj, baseCid)
}

// -----------------------------------------------------------------------------
// Render helpers
// -----------------------------------------------------------------------------

func renderEvent(path string, obj interface{}) string {
	_ = path // future: alter rendering based on path args
	event, ok := obj.(Schedule)
	if !ok {
		return "object is not an event"
	}
	var sb strings.Builder
	sb.WriteString("### " + event.Title + "\n")
	sb.WriteString(event.Thumbnail() + "\n\n")
	sb.WriteString(event.Description + "\n\n")
	sb.WriteString("[" + event.Cid() + "](?evt=" + event.Cid() + "&cal=" + event.CalendarCid + ")\n\n")
	sb.WriteString("**Status:** " + event.Status + "\n\n")
	sb.WriteString("**Date:** " + event.StartDate[:10] + "\n\n")
	sb.WriteString("**Location:** " + event.Location + "\n\n")

	// add the jsonld
	sb.WriteString("#### JSON-LD\n```json\n" + strings.TrimSpace(event.JsonLD().String()) + "\n```\n")

	return sb.String()
}

func renderCalendar(_ string, obj interface{}) string {
	calendar, ok := obj.(calendar)
	if !ok {
		return "object is not a calendar"
	}
	var sb strings.Builder
	sb.WriteString("### " + calendar.Title + "\n")
	sb.WriteString(calendar.Thumbnail() + "\n\n")
	// table of events keyed by CID
	sb.WriteString("| Date | Description |\n")
	sb.WriteString("| ---- | ----------- |\n")

	calendar.Events.IterateByOffset(0, calendar.Events.Size(), func(_ string, value any) bool {
		evt := value.(Schedule)
		sb.WriteString("| " + evt.StartDate[:10] + " | [" + evt.Description + "](?evt=" + evt.Cid() + "&cal=" + calendar.Cid() + ") |\n")
		return false
	})

	return sb.String()
}

func renderObject(path string, obj interface{}, baseCid string) string {
	// Normalize to a LogoGraph
	var lg LogoGraph
	switch v := obj.(type) {
	case LogoGraph:
		lg = v
	case Projectable:
		lg = v.Compose(v.FromPath(path))
	default:
		return "object is not renderable (no LogoGraph)"
	}

	ld := lg.JsonLD()

	var sb strings.Builder
	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString(lg.Thumbnail() + "\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")

	// CID block (with correct baseCid for commit)
	sb.WriteString("#### CID\n")
	cid := ld.Cid()

	// If a projection, offer commit button using the base CID
	if proj, ok := obj.(Projectable); ok {
		if _, found := calendarRegistry.Get(cid); !found {
			sb.WriteString(cid + "\n\n")
			// Use baseCid (registered origin), not the projected object's CID.
			sb.WriteString(
				eve.Button("Commit Projection:    "+tail(cid, 8),
					proj.ToPath(obj)+"&base="+baseCid+"&submit=register"+"\n"),
			)
		} else {
			sb.WriteString("[" + cid + "](" + proj.ToPath(obj) + ")\n")
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

func (o Schedule) String() string {
	return "Schedule{Status: " + o.Status +
		", StartDate: " + o.StartDate +
		", EndDate: " + o.EndDate +
		", Location: " + o.Location +
		", Description: " + o.Description + "}"
}

var OhrSchedule = Schedule{
	Status:      "EventScheduled",
	StartDate:   "2025-01-01T10:20:00Z",
	EndDate:     "2025-01-01T11:20:00Z",
	Location:    "Online",
	Title:       "AibLabs Office Hours",
	Description: "AibLabs Event Calendar: Join us for open discussion.",
	CalendarCid: "",
}

var _ LogoGraph = OhrSchedule
var _ Projectable = OhrSchedule

func (o Schedule) Cid(path ...string) string {
	return o.JsonLD(path...).Cid()
}

func (Schedule) renderOpts() map[string]any {
	return map[string]any{
		"dev":      map[string]any{},
		"labsnet1": map[string]any{},
	}
}

func (o Schedule) Image(path ...string) string {
	return "![OhrSchedule](" + o.DataUrl(path...) + ")"
}

func (o Schedule) DataUrl(path ...string) string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(o.SVG(path...))
}

func (o Schedule) Thumbnail(path ...string) string {
	return o.Image(path...)
}

// SVG renders a paper-shaped thumbnail with a centered clock and Office Hours text below.
func (Schedule) SVG(path ...string) string {
	_ = path // future: alter rendering based on path args
	return `
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
}

// ---- Composition helpers ----

func (Schedule) Coalesce(objs ...interface{}) Schedule {
	var merged Schedule
	for _, o := range objs {
		switch v := o.(type) {
		case []Schedule:
			for _, evt := range v {
				merged = mergeOhrSchedule(merged, evt)
			}
		case Schedule:
			merged = mergeOhrSchedule(merged, v)
		}
	}
	return merged
}

func mergeOhrSchedule(base, update Schedule) Schedule {
	if update.Status != "" {
		base.Status = update.Status
	}
	if update.StartDate != "" {
		base.StartDate = update.StartDate
	}
	if update.EndDate != "" {
		base.EndDate = update.EndDate
	}
	if update.Location != "" {
		base.Location = update.Location
	}
	if update.Title != "" {
		base.Title = update.Title
	}
	if update.Description != "" {
		base.Description = update.Description
	}
	return base
}

func (s Schedule) JsonLD(path ...string) eve.JsonLDMap {
	obj := OhrSchedule.FromPath(path...).(Schedule)
	start, end, status, location, descr := parseOhrScheduleOpts(obj)

	refUrl := "/r/labs000/officehours"
	if s.CalendarCid != "" {
        refUrl += "?cal=" + s.CalendarCid
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
			"url":   refUrl,
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

func parseOhrScheduleOpts(obj Schedule) (start, end time.Time, status, location, descr string) {
	start, err := time.Parse(time.RFC3339, obj.StartDate)
	if err != nil {
		start = time.Time{}
	}

	end, err = time.Parse(time.RFC3339, obj.EndDate)
	if err != nil || !end.After(start) {
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

// FromPath parses a query-style path (e.g., "?status=...&startDate=...").
func (Schedule) FromPath(path ...string) interface{} {
	q := eve.ParseQuery(strings.Join(path, ""))
	e := OhrSchedule
	if status, ok := q["status"]; ok && len(status) > 0 {
		e.Status = status[0]
	}
	if start, ok := q["startDate"]; ok && len(start) > 0 {
		e.StartDate = start[0]
	}
	if end, ok := q["endDate"]; ok && len(end) > 0 {
		e.EndDate = end[0]
	}
	if location, ok := q["location"]; ok && len(location) > 0 {
		e.Location = location[0]
	}
	if title, ok := q["title"]; ok && len(title) > 0 {
		e.Title = title[0]
	}
	if descr, ok := q["description"]; ok && len(descr) > 0 {
		e.Description = descr[0]
	}
	return e
}

func (Schedule) ToPath(obj ...interface{}) string {
	evt := OhrSchedule.Coalesce(obj)
	q := url.Values{}
	q.Set("cid", evt.Cid())
	if evt.Status != "" {
		q.Set("status", evt.Status)
	}
	if evt.StartDate != "" {
		q.Set("startDate", evt.StartDate)
	}
	if evt.EndDate != "" {
		q.Set("endDate", evt.EndDate)
	}
	if evt.Location != "" {
		q.Set("location", evt.Location)
	}
	if evt.Title != "" {
		q.Set("title", evt.Title)
	}
	if evt.Description != "" {
		q.Set("description", evt.Description)
	}
	return "?" + q.Encode()
}

func (Schedule) Compose(obj ...interface{}) LogoGraph {
	// Returns a concrete Schedule (which implements LogoGraph)
	return OhrSchedule.Coalesce(obj)
}

// Convenience flyer builder (unchanged semantics)
func (Schedule) Flyer(_ string, obj ...interface{}) *eve.Flyer {
	start, end, status, location, descr := parseOhrScheduleOpts(OhrSchedule.Coalesce(obj))
	f := &eve.Flyer{
		Name:      "Office Hours Schedule",
		Location:  &eve.Location{Name: location},
		StartDate: start,
		EndDate:   end,
		Status:    eve.EventStatus(status),
		Sessions:  []*eve.Session{{Title: "Main Session", Description: descr}},
		Images:    []string{},
	}
	f.SetRenderOpts(OhrSchedule.renderOpts())
	return f
}

func (Schedule) Heading() string {
	return "| CID | Description |\n| --- | ----------- |\n"
}

func (Schedule) Row(obj Schedule) string {
	return "| [" + obj.Cid() + "](?evt=" + obj.Cid() + ") | " + obj.Description + " |\n"
}

func (Schedule) Date(obj ...interface{}) string {
	evt := OhrSchedule.Coalesce(obj)
	start, _, _, _, _ := parseOhrScheduleOpts(evt)
	if start.IsZero() {
		return ""
	}
	return start.Format("2006-01-02")
}

// -----------------------------------------------------------------------------
// calendar (LogoGraph + Projectable passthrough)
// -----------------------------------------------------------------------------

type calendar struct {
	Title string
	Events *avl.Tree // key: event CID, value: Schedule
}

var eventCalendar = calendar{
	Title: "Gno.land Office Hours Calendar",
	Events: avl.NewTree(),
}

var _ LogoGraph = eventCalendar
var _ Projectable = eventCalendar

func init() {
	Register(eventCalendar, func(rec Record) {
		cal := rec.Object.(calendar)
		event := cal.Event(rec.Cid)
		cal.Events.Set(event.Cid(), event)   // Store by event's CID
	})
}

func (c calendar) Event(calendarCid string, _ ...string) Schedule {
	return Schedule{
		Status:      "EventPlanned",
		StartDate:   OhrSchedule.StartDate,
		EndDate:     OhrSchedule.EndDate,
		Title:       OhrSchedule.Title,
		Description: OhrSchedule.Description,
		Location:    "Gnowhere",
		CalendarCid: calendarCid,
	}
}

// LogoGraph forwards to schedule visuals (placeholder)
func (calendar) Cid(path ...string) string           { return eventCalendar.JsonLD(path...).Cid() }
func (calendar) Image(path ...string) string         { return OhrSchedule.Image(path...) }
func (calendar) DataUrl(path ...string) string       { return OhrSchedule.DataUrl(path...) }
func (calendar) Thumbnail(path ...string) string     { return OhrSchedule.Thumbnail(path...) }
func (calendar) SVG(path ...string) string           { return OhrSchedule.SVG(path...) }
func (calendar) JsonLD(path ...string) eve.JsonLDMap { return OhrSchedule.JsonLD(path...) }

// Projectable passthrough
func (calendar) FromPath(path ...string) interface{} { return OhrSchedule.FromPath(path...) }
func (calendar) ToPath(obj ...interface{}) string    { return OhrSchedule.ToPath(obj...) }
func (calendar) Compose(obj ...interface{}) LogoGraph {
	return OhrSchedule.Coalesce(eventCalendar.Event(""), obj)
}
func (calendar) Coalesce(obj ...interface{}) calendar {
	if len(obj) == 0 || obj[0] == nil {
		return eventCalendar
	}
	if c, ok := obj[0].(calendar); ok {
		return c
	}
	panic("invalid calendar object")
}
func (calendar) Heading() string { return "| Calendar |\n| -------- |\n" }
func (calendar) Row(obj calendar) string {
	return "| [" + obj.Title + "](./officehours?cal=" + obj.Cid() + ") | "
}
func (calendar) RenderTable() string {
	if calendarRegistry.Size() == 0 {
		return "No calendars registered."
	}
	var sb strings.Builder
	sb.WriteString(eventCalendar.Heading())

	calendarRegistry.IterateByOffset(0, calendarRegistry.Size(), func(_ string, value any) bool {
		rec, ok := value.(Record)
		if !ok {
			return false
		}
		if cal, isCalendar := rec.Object.(calendar); isCalendar {
			sb.WriteString(eventCalendar.Row(cal))
		}
		return false
	})
	return sb.String()
}
