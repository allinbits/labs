package logoverse

import (
	"net/url"
	"time"

	eve "gno.land/p/eve000/event/component"
)

type EventObj struct {
	Status    string
	StartDate string
	EndDate   string
	Settings  map[string]string
}

var Event = EventObj{
	Status:    "EventScheduled",
	StartDate: "2025-01-01T13:00:00Z",
	EndDate:   "2025-01-01T13:00:00Z",
	Settings: map[string]string{
		"location":    "Online",
		"description": "Immutable object used to compose event flyers in gno.land.",
	},
}

var _ LogoGraph = Event
var _ Projectable = Event

func (EventObj) Cid() string {
	return Event.Compose().Cid()
}

func (EventObj) renderOpts() map[string]any {
	return map[string]any{
		"dev":      map[string]any{}, // REVIEW: chainIds are used to provide a chain-level obj namespace
		"labsnet1": map[string]any{},
	}
}

func (EventObj) Image() string {
	return "![Event](" + Event.DataUrl() + ")"
}

func (EventObj) DataUrl() string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(Event.SVG())
}

func (EventObj) Thumbnail() string {
	return "![Event](" + Event.ThumbnailDataUrl() + ")"
}

func (EventObj) ThumbnailDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(Event.ThumbnailSvg("75", "94"))
}

func (EventObj) ThumbnailSvg(w, h string) string {
	encodedSvg := url.PathEscape(Event.SVG())
	fileIcon := `<svg id="` + Event.Cid() + `" width="` + w + `" height="` + h + `" xmlns="http://www.w3.org/2000/svg">
        <g>
            <!-- Main paper body -->
            <path d="M4,0 h` + w + ` v` + h + ` h-` + w + ` z" fill="#fff" stroke="#ccc" stroke-width="1"/>
            <!-- Folded corner -->
            <path d="M4,0 l12,0 l-12,12 z" fill="#f0f0f0" stroke="#ccc" stroke-width="1"/>
        </g>
        <text x="12" y="82" font-size="14" font-weight="bold" fill="#666">eve.Flyer</text>

        <image href="data:image/svg+xml;utf8,` + encodedSvg + `"
               x="12" y="5"
               width="calc(` + w + ` - 24)"
               height="calc(` + h + ` - 32)"/>
    </svg>`
	return fileIcon
}

func (EventObj) SVG() string {
	return AibLabs.SVG()
}

func (EventObj) mergeOpts(objs []interface{}) EventObj {
	obj := make([]EventObj, 0, len(objs))
	for _, o := range objs {
		if evt, ok := o.(EventObj); ok {
			obj = append(obj, evt)
		}
	}
	e := Event
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
		for k, v := range o.Settings {
			e.Settings[k] = v
		}
	}
	return e
}

func (EventObj) JsonLD() eve.JsonLDMap {
	return Event.Compose()
}

func parseEventOpts(obj EventObj) (start, end time.Time, status, location, descr string) {
	start, _ = time.Parse(time.RFC3339, obj.StartDate)
	end, _ = time.Parse(time.RFC3339, obj.EndDate)
	if !end.After(start) {
		end = start
	}
	status = string(obj.Status)
	location = "Online"
	if loc, ok := obj.Settings["location"]; ok {
		location = loc
	}
	descr = "This is an example event flyer generated as code in gno.land."
	if d, ok := obj.Settings["description"]; ok {
		descr = d
	}
	return
}

// FromPath parses event options from a URL path query string and returns an EventObj with those options set.
func (EventObj) FromPath(path string) interface{} {
	q := eve.ParseQuery(path)
	e := Event
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
		e.Settings["location"] = location[0]
	}
	if descr, ok := q["description"]; ok && len(descr) > 0 {
		e.Settings["description"] = descr[0]
	}
	return e
}

func (EventObj) ToPath(obj ...interface{}) string {
	evt := Event.mergeOpts(obj)
	q := url.Values{}
	q.Set("cid", evt.Cid())
	if evt.Status != "" {
		q.Set("status", evt.Status) // TODO: remove schema.org prefix?
	}
	if evt.StartDate != "" {
		q.Set("startDate", evt.StartDate)
	}
	if evt.EndDate != "" {
		q.Set("endDate", evt.EndDate)
	}
	if loc, ok := Event.Settings["location"]; ok && loc != "" {
		q.Set("location", loc)
	}
	if descr, ok := Event.Settings["description"]; ok && descr != "" {
		q.Set("description", descr)
	}
	return "?" + q.Encode()
}

func (EventObj) Compose(obj ...interface{}) eve.JsonLDMap {
	start, end, status, location, descr := parseEventOpts(Event.mergeOpts(obj))
	return eve.JsonLDMap{
		"@context":             "https://schema.org",
		"@type":                "ImageObject",
		"name":                 "Event",
		"description":          descr,
		"representativeOfPage": true,
		"about": map[string]interface{}{
			"@type":       "Event",
			"name":        "Event Flyer",
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

func (EventObj) Flyer(obj ...interface{}) *eve.Flyer {
	start, end, status, location, descr := parseEventOpts(Event.mergeOpts(obj))
	f := &eve.Flyer{
		Name:      "Event",
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
	f.SetRenderOpts(Event.renderOpts())
	return f
}
