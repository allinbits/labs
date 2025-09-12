package logoverse

import (
	"net/url"
	"time"

	eve "gno.land/p/eve000/event/component"
)

type EventOpts struct {
	Status    string
	StartDate string
	EndDate   string
	Settings  map[string]string
}

var Event = EventOpts{
	Status:    "EventScheduled", // FIXME: not showing up in metadata
	StartDate: "2025-01-01T13:00:00Z",
	EndDate:   "2025-01-01T13:00:00Z",
	Settings:  map[string]string{
        "location": "Online",
        "description": "Immutable object used to compose event flyers in gno.land.",
    },
}

var _ LogoGraph = EventOpts{}

func (EventOpts) Cid() string {
	return Event.WithOpts().Cid()
}

func (EventOpts) RenderOpts() map[string]any {
	return map[string]any{
		"dev":      map[string]any{}, // REVIEW: chainIds are used to provide a chain-level opts namespace
		"labsnet1": map[string]any{},
	}
}

func (EventOpts) Flyer(ef ...EventOpts) *eve.Flyer {
	var evt EventOpts
	if len(ef) > 0 {
		evt = ef[0]
	} else {
		evt = Event
	}
	start, _ := time.Parse(time.RFC3339, evt.StartDate)
	end, _ := time.Parse(time.RFC3339, evt.EndDate)
	if !end.After(start) {
		end = start
	}
	location := "Online"
	if loc, ok := Event.Settings["location"]; ok {
		location = loc
	}
	descr := "This is an example event flyer generated as code in gno.land."
	if d, ok := Event.Settings["description"]; ok {
	    descr = d
    }
	f := &eve.Flyer{
		Name:      "Event Flyer",
		Location:  &eve.Location{Name: location},
		StartDate: start,
		EndDate:   end,
		Status:    eve.EventStatus(Event.Status),
		Sessions: []*eve.Session{
			{
				Title:       "Main Session",
                Description: descr,
			},
		},
		Images: []string{},
	}
	f.SetRenderOpts(Event.RenderOpts())
	return f
}

func (EventOpts) Image() string {
	return "![Event](" + Event.DataUrl() + ")"
}

func (EventOpts) DataUrl() string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(Event.SVG())
}

func (EventOpts) Thumbnail() string {
	return "![Event](" + Event.ThumbnailDataUrl() + ")"
}

func (EventOpts) ThumbnailDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(Event.ThumbnailSvg("75", "94"))
}

func (EventOpts) ThumbnailSvg(w, h string) string {
	encodedSvg := url.PathEscape(Event.SVG())
	fileIcon := `<svg id="` + Event.Cid() + `" width="` + w + `" height="` + h + `" xmlns="http://www.w3.org/2000/svg">
    <script type="application/ld+json">
    ` + Event.WithOpts().String() + `
    </script>
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

func (EventOpts) SVG() string {
	return AibLabs.SVG()
}

func (EventOpts) MergeOpts(opts []EventOpts) EventOpts {
    e := Event
    for _, o := range opts {
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

func (EventOpts) WithOpts(opts ...EventOpts) eve.JsonLDMap {
    eventOpts := Event.MergeOpts(opts)
	start, _ := time.Parse(time.RFC3339, eventOpts.StartDate)
	end, _ := time.Parse(time.RFC3339, eventOpts.EndDate)
	if !end.After(start) {
		end = start
	}
	location := "Online"
	if loc, ok := eventOpts.Settings["location"]; ok {
		location = loc
	}
	descr := "This is an example event flyer generated as code in gno.land."
	if d, ok := eventOpts.Settings["description"]; ok {
		descr = d
	}
	// REVIEW: consider using eve.Flyer.ToJsonLD() to populate about section
	return eve.JsonLDMap{
		"@context": "https://schema.org",
		"@type":    "ImageObject",
		"name":     "Event Flyer",
		"description": descr,
		"representativeOfPage": true,
		"about": map[string]interface{}{
			"@type":       "Event",
			"name":        "Event Flyer",
			"description": descr,
			"eventStatus": string(eventOpts.Status),
			"startDate":   start.Format(time.RFC3339),
			"endDate":     end.Format(time.RFC3339),
			"location": map[string]interface{}{
				"@type":   "Place",
				"name":    location,
				"address": location,
			},
		},
	}
}

func (EventOpts) JsonLD() eve.JsonLDMap {
	return Event.WithOpts()
}
