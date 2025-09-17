package officehours

import (
	"net/url"
	"strings"
	"time"

	eve "gno.land/p/eve000/event/component"
)

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

var _ LogoGraph   = OhrSchedule
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
	if update.Status != "" { base.Status = update.Status }
	if update.StartDate != "" { base.StartDate = update.StartDate }
	if update.EndDate != "" { base.EndDate = update.EndDate }
	if update.Location != "" { base.Location = update.Location }
	if update.Description != "" { base.Description = update.Description }
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
	if err != nil { start = time.Time{} }

	end, err = time.Parse(time.RFC3339, obj.EndDate)
	if err != nil || !end.After(start) { end = start }

	status = obj.Status
	location = obj.Location
	if location == "" { location = "Online" }

	descr = obj.Description
	if descr == "" { descr = "AibLabs Event Calendar: Join us for open discussion." }

	return
}

// FromPath parses a query-style path (e.g., "?status=...&startDate=...").
func (Schedule) FromPath(path ...string) interface{} {
	q := eve.ParseQuery(strings.Join(path, ""))
	e := OhrSchedule
	if status, ok := q["status"]; ok && len(status) > 0 { e.Status = status[0] }
	if start, ok := q["startDate"]; ok && len(start) > 0 { e.StartDate = start[0] }
	if end, ok := q["endDate"]; ok && len(end) > 0 { e.EndDate = end[0] }
	if location, ok := q["location"]; ok && len(location) > 0 { e.Location = location[0] }
	if descr, ok := q["description"]; ok && len(descr) > 0 { e.Description = descr[0] }
	return e
}

func (Schedule) ToPath(obj ...interface{}) string {
	evt := OhrSchedule.Coalesce(obj)
	q := url.Values{}
	q.Set("cid", evt.Cid())
	if evt.Status != "" { q.Set("status", evt.Status) }
	if evt.StartDate != "" { q.Set("startDate", evt.StartDate) }
	if evt.EndDate != "" { q.Set("endDate", evt.EndDate) }
	if evt.Location != "" { q.Set("location", evt.Location) }
	if evt.Description != "" { q.Set("description", evt.Description) }
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
		Sessions: []*eve.Session{{ Title: "Main Session", Description: descr }},
		Images:   []string{},
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