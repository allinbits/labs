package logoverse

import (
    "time"
    "net/url"
	eve "gno.land/p/eve000/event/component"
)

type eventFlyer struct {
    Status    string
    StartDate string
    EndDate   string
    Settings  map[string]string
}

var Event = eventFlyer{
    Status:    "EventScheduled",
    StartDate: "2025-01-01T13:00:00Z",
    EndDate:   "2025-01-01T13:00:00Z",
    Settings:  map[string]string{"location": "Online"},
}

var _ = eve.Flyer{} // ensure eve imported
var _ Logo = eventFlyer{}

func (eventFlyer) Cid() string {
    return Event.Flyer().Cid()
}

func (eventFlyer) Flyer() *eve.Flyer {
    start, _ := time.Parse(time.RFC3339, Event.StartDate)
    end, _ := time.Parse(time.RFC3339, Event.EndDate)
    return &eve.Flyer{
        Name:      "Event Flyer",
        StartDate: start,
        EndDate:   end,
        Sessions: []*eve.Session{
            {
                Description: "This is a proposed event flyer.",
                Body: []eve.Content{
                    {
                        Published: true,
                        Callback: func(_ string) string {
                            return "This is a placeholder for the proposed event details."
                        },
                    },
                },
            },
        },
    }
}

func (eventFlyer) Image() string {
    return "![Event](" + Event.DataUrl() + ")"
}

func (eventFlyer) DataUrl() string {
    return "data:image/svg+xml;charset=utf-8," + url.PathEscape(Event.SVG())
}

func (eventFlyer) Thumbnail() string {
    return "![Event](" + Event.ThumbnailDataUrl() + ")"
}

func (eventFlyer) ThumbnailDataUrl() string {
    return "data:image/svg+xml;utf8," + url.PathEscape(Event.ThumbnailSvg("75", "94"))
}

func (eventFlyer) ThumbnailSvg(w, h string) string {
    encodedSvg := url.PathEscape(AibLabs.SVG())
    fileIcon := `<svg id="` + Event.Cid() + `" width="` + w + `" height="` + h + `" xmlns="http://www.w3.org/2000/svg">
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

func (eventFlyer) SVG() string {
    // Derivative SVG, e.g., add event icon or text overlay
    return `<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120">
        <rect width="100%" height="100%" fill="#f0f0f0"/>
        <text x="10" y="60" font-size="16" fill="#333">Event Flyer</text>
        <!-- Optionally embed AibLabs SVG or elements here -->
    </svg>`
}

func (e eventFlyer) JsonLD() JsonLDMap {
    return JsonLDMap{
        "@context":    "https://schema.org",
        "@type":       "Event",
        "name":        "Event Flyer",
        "description": "This is a proposed event flyer.",
        "eventStatus": eve.Status(e.Status),
        "startDate":   e.StartDate,
        "endDate":     e.EndDate,
        "location": map[string]interface{}{
            "@type":   "Place",
            "name":    e.Settings["location"],
            "address": e.Settings["location"],
        },
    }
}