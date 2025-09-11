package logoverse

import (
    "time"
    "net/url"
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
    Settings:  map[string]string{"location": "Online"},
}

var _ = eve.Flyer{} // ensure eve imported
var _ Logo = EventOpts{}

func (EventOpts) Cid() string {
    return Event.WithFlyer(Event.Flyer()).Cid()
}

func (EventOpts)RenderOpts() map[string]any {
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
    f := &eve.Flyer{
        Name:      "Event Flyer",
        Location:  &eve.Location{Name: location},
        StartDate: start,
        EndDate:   end,
        Status:    eve.EventStatus(Event.Status),
        Description: "This is an example event flyer generated as code in gno.land. " +
            "It can be stored, versioned, and composed directly, without extra boilerplate or access control.",
        Sessions: []*eve.Session{
            {
                Title:        "Main Session",
                Description: "This is the main session of the event.",
            },
        },
        Images:     []string{},
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
    ` + Event.WithFlyer(Event.Flyer()).String() + `
    </script>
        <!-- Paper with folded corner -->
        <g>
            <!-- Main paper body -->
            <path d="M4,0 h` + w + ` v` + h + ` h-` + w + ` z" fill="#fff" stroke="#ccc" stroke-width="1"/>
            <!-- Folded corner -->
            <path d="M4,0 l12,0 l-12,12 z" fill="#f0f0f0" stroke="#ccc" stroke-width="1"/>
        </g>
        <text x="12" y="82" font-size="14" font-weight="bold" fill="#666">eve.Flyer</text>

        <!-- Embedded event content -->
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

func (EventOpts) WithFlyer(ef *eve.Flyer) JsonLDMap {
    start := ef.StartDate.Format(time.RFC3339)
    end := ef.EndDate.Format(time.RFC3339)
    if !ef.EndDate.After(ef.StartDate) {
        end = start
    }
    location := "Online"
    return JsonLDMap{
        "@context":    "https://schema.org",
        "@type":       "Event",
        "name":        ef.Name,
        "description": ef.Sessions[0].Description,
        "eventStatus": string(ef.Status),
        "startDate":   start,
        "endDate":     end,
        "location": map[string]interface{}{
            "@type":   "Place",
            "name":    location,
            "address": location,
        },
    }
}

func (EventOpts) JsonLD() JsonLDMap {
    return Event.WithFlyer(Event.Flyer())
}