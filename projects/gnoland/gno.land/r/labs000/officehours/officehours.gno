package officehours

import (
	"net/url"
	"time"
	"strings"

	eve "gno.land/p/eve000/event/component"
)

type OfficeHoursObj struct {
	Status      string
	StartDate   string
	EndDate     string
	Location    string
	Description string
}

var OfficeHours = OfficeHoursObj{
	Status:      "EventScheduled",
	StartDate:   "2025-01-01T10:20:00Z",
	EndDate:     "2025-01-01T11:20:00Z",
	Location:    "Online",
	Description: "AibLabs Office Hours: Join us for open discussion.",
}

var _ LogoGraph = OfficeHours
var _ Projectable = OfficeHours

func (OfficeHoursObj) Cid(_ ...string) string {
    // FIXME: pass in string
	return OfficeHours.Compose().(LogoGraph).Cid()
}

func (OfficeHoursObj) renderOpts() map[string]any {
	return map[string]any{
		"dev":      map[string]any{},
		"labsnet1": map[string]any{},
	}
}

func (OfficeHoursObj) Image(_ ...string) string {
	return "![OfficeHours](" + OfficeHours.DataUrl() + ")"
}

func (OfficeHoursObj) DataUrl(_ ...string) string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(OfficeHours.SVG())
}

func (OfficeHoursObj) Thumbnail(_ ...string) string {
	return OfficeHours.Image()
}

// SVG renders a paper-shaped thumbnail with a centered clock and Office Hours text below.
func (OfficeHoursObj) SVG(_ ...string) string {
	return `
<svg width="300" height="200" viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Paper shape with slight shadow -->
  <rect x="20" y="20" width="260" height="160" rx="18" ry="18" fill="#fff" stroke="#bbb" stroke-width="3" filter="url(#shadow)"/>
  <defs>
    <filter id="shadow" x="0" y="0" width="200%" height="200%">
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#888" flood-opacity="0.18"/>
    </filter>
  </defs>
  <!-- Centered clock -->
  <g transform="translate(150,90)">
    <circle cx="0" cy="0" r="48" fill="#fff" stroke="#222" stroke-width="4"/>
    <line x1="0" y1="0" x2="-32" y2="-26" stroke="#222" stroke-width="6" stroke-linecap="round"/>
    <line x1="0" y1="0" x2="32" y2="16" stroke="#222" stroke-width="4" stroke-linecap="round"/>
    <circle cx="0" cy="0" r="6" fill="#222"/>
  </g>
  <!-- Office Hours text below the clock -->
  <text x="150" y="170" text-anchor="middle" font-size="32" font-weight="bold" fill="#222">Office Hours</text>
</svg>
`
}

// TODO: add to interface? - no it returns a struct and not an interface
func (OfficeHoursObj) Coalesce(objs ...interface{}) OfficeHoursObj {
	obj := make([]OfficeHoursObj, 0, len(objs))
	for _, o := range objs {
	    if evtList, ok := o.([]OfficeHoursObj); ok {
	                obj = append(obj, evtList...)
	    } else if evt, ok := o.(OfficeHoursObj); ok {
			obj = append(obj, evt)
		}
	}
	e := OfficeHours
	for _, o := range obj {
		if o.Status != "" {
			e.Status = o.Status
		}
		if o.StartDate != "" {
			e.StartDate = o.StartDate
		}
		if o.EndDate != "" {
			e.EndDate = o.EndDate
		}
		if o.Location != "" {
			e.Location = o.Location
		}
		if o.Description != "" {
			e.Description = o.Description
		}
	}
	return e
}

func (OfficeHoursObj) JsonLD(path ...string) eve.JsonLDMap {
    obj := OfficeHours.FromPath(path...).(OfficeHoursObj)
	start, end, status, location, descr := parseOfficeHoursOpts(OfficeHours.Coalesce(obj))
	return eve.JsonLDMap{
		"@context":             "https://schema.org",
		"@type":                "ImageObject",
		"name":                 "OfficeHours",
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

func parseOfficeHoursOpts(obj OfficeHoursObj) (start, end time.Time, status, location, descr string) {
	start, _ = time.Parse(time.RFC3339, obj.StartDate)
	end, _ = time.Parse(time.RFC3339, obj.EndDate)
	if !end.After(start) {
		end = start
	}
	status = string(obj.Status)
	location = "Online"
	if obj.Location != "" {
		location = obj.Location
	}
	descr = "AibLabs Office Hours: Join us for open discussion."
	if obj.Description != "" {
		descr = obj.Description
	}
	return
}

func (OfficeHoursObj) FromPath(path ...string) interface{} {
	q := eve.ParseQuery(strings.Join(path, ""))
	e := OfficeHours
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

func (OfficeHoursObj) ToPath(obj ...interface{}) string {
	evt := OfficeHours.Coalesce(obj)
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
	if OfficeHours.Location != "" {
		q.Set("location", OfficeHours.Location)
	}
	if OfficeHours.Description != "" {
		q.Set("description", OfficeHours.Description)
	}
	return "?" + q.Encode()
}

func (OfficeHoursObj) Compose(obj ...interface{}) interface{} {
    return OfficeHours.Coalesce(obj)
}

func (OfficeHoursObj) Flyer(path string, obj ...interface{}) *eve.Flyer {
    _ = path // FIXME
    // TODO: support copy from eve.Event if passed in
	start, end, status, location, descr := parseOfficeHoursOpts(OfficeHours.Coalesce(obj))
	f := &eve.Flyer{
		Name:      "OfficeHours",
		Location:  &eve.Location{Name: location},
		StartDate: start,
		EndDate:   end,
		Status:    eve.EventStatus(status),
		Sessions: []*eve.Session{
			{
				Title:       "Main Session",
				Description: descr,
			},
		},
		Images: []string{},
	}
	f.SetRenderOpts(OfficeHours.renderOpts())
	return f
}
