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

var calendarRegistry = avl.NewTree()

type Counter struct{ Count int64 }

func (c *Counter) Next() string   { c.Count++; return c.String() }
func (c *Counter) String() string { return ufmt.Sprintf("%08d", c.Count) }

var counter = Counter{Count: 0}

// ---- Interfaces ----

type Editable interface {
	RenderForm(...string) string
}

type Projectable interface {
	ToPath(...interface{}) string
	FromPath(...string) interface{}
	Compose(...interface{}) interface{} // should return a value implementing LogoGraph
}

type LogoGraph interface {
	SVG(...string) string
	JsonLD(...string) eve.JsonLDMap
	Cid(...string) string
	Thumbnail(...string) string
}

// ---- Records ----

type Record struct {
	Name        string
	Description string
	Cid         string
	Object      interface{}
	Committer   string
	Seq         int64
}

// ---- Projection plumbing ----

// EmitProjectionEvent validates + emits, but does not register the projection.
func EmitProjectionEvent(base, path, seal string) (cid string) {
	return commitProjection(true, base, path, seal)
}

// CommitProjection validates + registers a projected object derived from base+path.
func CommitProjection(_ realm, base, path, seal string) (cid string) {
	return commitProjection(false, base, path, seal)
}

func commitProjection(emitOnly bool, base, path, seal string) (cid string) {
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
		return "base CID not found"
	}
	r := v.(Record)

	proj, isProj := r.Object.(Projectable)
	if !isProj {
		panic("object is not projectable")
	}

	// Build the projected object
	projected := proj.FromPath(path)
	// Compose to a LogoGraph (your Compose returns OhrScheduleObj, which implements LogoGraph)
	lg, ok := proj.Compose(projected).(LogoGraph)
	if !ok {
		panic("Compose(...) must return an object implementing LogoGraph")
	}
	cid = lg.JsonLD().Cid()

	if seal != cid {
		panic("invalid seal: expected " + cid + " but got " + seal)
	}
	if _, ok := calendarRegistry.Get(cid); ok {
		panic("duplicate projected CID registered: " + cid)
	}

	rec := Record{
		Name:        r.Name + " (projected)",
		Description: r.Description + " (projected)",
		Cid:         cid,
		Object:      projected,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         counter.Count + 1,
	}

	std.Emit("ProjectionEvent", "cid", cid, "seal", seal, "seq", counter.Next())
	if !emitOnly {
		calendarRegistry.Set(rec.Cid, rec)
	}
	return
}

// ---- Register ----

// Register adds a LogoGraph object to the calendarRegistry and returns its CID.
func Register(i interface{}, callback ...func(rec Record)) string {
	lg, ok := i.(LogoGraph)
	if !ok {
		panic("object must implement LogoGraph interface")
	}
	newCid := lg.Cid()
	if !eve.IsCIDv1(newCid) {
		panic("object must have a likely CIDv1 (base32, 'baf...' style)")
	}

	// Touch media to smoke-test
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

	rec := Record{
		Name:        ld.StringVal(columns[1]),
		Description: ld.StringVal(columns[2]),
		Cid:         newCid,
		Object:      i,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         counter.Count + 1,
	}
	if _, ok := calendarRegistry.Get(rec.Cid); ok {
		panic("duplicate CID registered: " + rec.Cid)
	}
	calendarRegistry.Set(rec.Cid, rec)
	std.Emit("Register", "cid", rec.Cid, "seq", counter.Next())
	for _, cb := range callback {
		cb(rec)
	}
	return newCid
}

var columns = []string{"cid", "name", "description", "committer"}

func (e Record) String() string {
	return "| [" + e.Cid[len(e.Cid)-8:] + "](?cid=" + e.Cid + ") | " + e.Name + " | " + e.Description + " | [" + e.Committer[len(e.Committer)-8:] + "](/u/" + e.Committer + ") |\n"
}

// ---- Render router ----

func Render(path string) string {
	q := eve.ParseQuery(path)

	cal, hasCal := q["cal"]
	if hasCal {
		if calObj, ok := calendarRegistry.Get(cal[0]); ok {
			if rec, ok := calObj.(Record); ok {
				if c, ok := rec.Object.(calendar); ok {
					if event, hasEvent := q["evt"]; hasEvent {
						if evtObj, ok := c.Dates.Get(event[0]); ok {
							return renderEvent(path, evtObj)
						} else {
							return "event cid not found: " + event[0]
						}
					}
				}
				return renderCalendar(path, rec.Object)
			} else {
				return "invalid calendar record"
			}
		} else {
			return "cal cid not found: " + cal[0]
		}
	}

	cid, hasCid := q["cid"]
	if !hasCid {
		if len(q["v"]) == 1 && q["v"][0] == "seq" {
			return counter.String()
		}
		return eventCalendar.RenderTable()
	}

	if submit, hasSubmit := q["submit"]; hasSubmit && submit[0] == "register" {
		if base, hasBase := q["base"]; hasBase && eve.IsCIDv1(base[0]) {
			if v, ok := calendarRegistry.Get(base[0]); ok {
				r := v.(Record)
				if ed, isEd := r.Object.(Editable); isEd {
					form := ed.RenderForm(path)
					if form != "" {
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

	v, found := calendarRegistry.Get(cid[0])
	if !found {
		return "cid not found"
	}

	r := v.(Record)
	obj := r.Object
	proj, isProj := r.Object.(Projectable)
	if isProj {
		obj = proj.FromPath(path)
	}

	if format, ok := q["v"]; ok {
		switch format[0] {
		case "ldjson":
			ld := obj.(LogoGraph).JsonLD()
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
			if isProj {
				return "[" + proj.Compose(obj).(LogoGraph).JsonLD().Cid() + "](?cid=" + proj.Compose(obj).(LogoGraph).JsonLD().Cid() + ")"
			}
			return "[" + r.Cid + "](?cid=" + r.Cid + ")"

		case "seq":
			return ufmt.Sprintf("%d", r.Seq)

		case "committer":
			return r.Committer

		case "svg":
			return obj.(LogoGraph).SVG()

		case "thumbnail":
			return obj.(LogoGraph).Thumbnail()

		case "json":
			if isProj {
				return proj.Compose(obj).(LogoGraph).JsonLD().String()
			}
			return obj.(LogoGraph).JsonLD().String()
		}
	}

	// Optional seal verification
	if seal, ok := q["seal"]; ok && isProj {
		if !eve.IsCIDv1(seal[0]) {
			return "invalid seal: not a CIDv1"
		}
		calc := proj.Compose(obj).(LogoGraph).JsonLD().Cid()
		if seal[0] != calc {
			return "invalid seal: expected " + calc + " but got " + seal[0]
		}
	}

	return renderObject(path, obj)
}

func renderEvent(path string, obj interface{}) string {
	event, ok := obj.(Schedule)
	if !ok {
		return "object is not an event"
	}
	var sb strings.Builder
	sb.WriteString("### " + event.Title + "\n")
	sb.WriteString(event.Thumbnail() + "\n\n")
	sb.WriteString(event.Description + "\n\n")
	sb.WriteString("**Status:** " + event.Status + "\n\n")
	sb.WriteString("**Date:** " + event.StartDate[:10] + "\n\n")
	sb.WriteString("**Location:** " + event.Location + "\n\n")
	return sb.String()
}

func renderCalendar(path string, obj interface{}) string {
	calendar, ok := obj.(calendar)
	if !ok {
		return "object is not a calendar"
	}
	var sb strings.Builder
	sb.WriteString("### " + calendar.Title + "\n")
	sb.WriteString(calendar.Thumbnail() + "\n\n")
	// add a table of events
	sb.WriteString("| Date | Description |\n")
	sb.WriteString("| ---- | ----------- |\n")

	calendar.Dates.IterateByOffset(0, calendar.Dates.Size(), func(_ string, value any) bool {
		evt := value.(Schedule)
		// REVIEW: consider using ?event={cid} for event links
		sb.WriteString("| " + evt.StartDate[:10] + " | [" + evt.Description + "](?evt=" + evt.Cid() + "&cal=" + calendar.Cid() + ") |\n")
		return false
	})

	return sb.String()
}

func renderObject(path string, obj interface{}) string {
	glyph := obj.(LogoGraph)

	var ld eve.JsonLDMap
	if proj, ok := obj.(Projectable); ok {
		ld = proj.Compose(proj.FromPath(path)).(LogoGraph).JsonLD()
	} else {
		ld = glyph.JsonLD()
	}

	var sb strings.Builder
	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString(glyph.Thumbnail() + "\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")

	sb.WriteString("#### CID\n")
	cid := ld.Cid()
	if proj, ok := obj.(Projectable); ok {
		if _, found := calendarRegistry.Get(cid); !found {
			sb.WriteString(cid + "\n\n")
			sb.WriteString(eve.Button("Commit Projection:    "+cid[len(cid)-8:], proj.ToPath(obj)+"&base="+glyph.Cid()+"&submit=register"+"\n"))
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

type Schedule struct {
	Status      string
	StartDate   string
	EndDate     string
	Location    string
	Title       string
	Description string
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
	if update.Description != "" {
		base.Description = update.Description
	}
	return base
}

func (Schedule) JsonLD(path ...string) eve.JsonLDMap {
	obj := OhrSchedule.FromPath(path...).(Schedule)
	start, end, status, location, descr := parseOhrScheduleOpts(obj)
	return eve.JsonLDMap{
		"@context":             "https://schema.org",
		"@type":                "ImageObject",
		"name":                 "Calendar",
		"description":          descr,
		"url":                  "/r/labs000/officehours",
		"representativeOfPage": true,
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
	if evt.Description != "" {
		q.Set("description", evt.Description)
	}
	return "?" + q.Encode()
}

func (Schedule) Compose(obj ...interface{}) interface{} {
	// Returns a concrete Schedule (which implements LogoGraph)
	return OhrSchedule.Coalesce(obj)
}

// Convenience flyer builder (unchanged semantics)
func (Schedule) Flyer(path string, obj ...interface{}) *eve.Flyer {
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

// TODO: this should have a list of Dates
type calendar struct {
	Title string
	Dates *avl.Tree // key: date string, value: Schedule
}

var eventCalendar = calendar{
	Title: "Gno.land Office Hours Calendar",
	Dates: avl.NewTree(),
}

var _ LogoGraph = eventCalendar
var _ Projectable = eventCalendar

func init() {
	Register(eventCalendar, func(rec Record) {
		cal := rec.Object.(calendar)
		cal.Dates.Set(rec.Cid, cal.Event())
	})
}

func (c calendar) Event(path ...string) Schedule {
	return Schedule{
		Status:      "EventPlanned",
		StartDate:   OhrSchedule.StartDate,
		EndDate:     OhrSchedule.EndDate,
		Title:       OhrSchedule.Title,
		Description: OhrSchedule.Description,
		Location:    "Gnowhere",
	}
}

func (calendar) Cid(path ...string) string           { return eventCalendar.JsonLD(path...).Cid() }
func (calendar) Image(path ...string) string         { return OhrSchedule.Image(path...) }
func (calendar) DataUrl(path ...string) string       { return OhrSchedule.DataUrl(path...) }
func (calendar) Thumbnail(path ...string) string     { return OhrSchedule.Thumbnail(path...) }
func (calendar) SVG(path ...string) string           { return OhrSchedule.SVG(path...) }
func (calendar) JsonLD(path ...string) eve.JsonLDMap { return OhrSchedule.JsonLD(path...) }

// ---- Projectable passthrough ----

func (calendar) FromPath(path ...string) interface{} { return OhrSchedule.FromPath(path...) }
func (calendar) ToPath(obj ...interface{}) string    { return OhrSchedule.ToPath(obj...) }
func (calendar) Compose(obj ...interface{}) interface{} {
	return OhrSchedule.Coalesce(eventCalendar.Event(), obj)
}

func (calendar) RenderTable() string {
	if calendarRegistry.Size() == 0 {
		return "No calendars registered."
	}

	var sb strings.Builder
	sb.WriteString(eventCalendar.Heading())

	calendarRegistry.IterateByOffset(0, calendarRegistry.Size(), func(key string, value any) bool {
		rec, ok := value.(Record)
		if !ok {
			return false // skip non-Record entries
		}

		if cal, isCalendar := rec.Object.(calendar); isCalendar {
			sb.WriteString(eventCalendar.Row(cal))
		}
		return false
	})

	return sb.String()
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

func (calendar) Heading() string {
	return "| Calendar | \n" + "| ------------- |\n"
}

func (calendar) Row(obj calendar) string {
	return "| [" + obj.Title + "](./officehours?cal=" + obj.Cid() + ") | "
}
