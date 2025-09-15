package officehours

import (
	eve "gno.land/p/eve000/event/component"
	logo "gno.land/r/labs000/logoverse"
)

var cid string

func init() {
    cid = logo.Register(event)
}

func Render(path string) string {
    return logo.Render("?cid=" + cid)
}

type episode struct {
    Event logo.OfficeHoursEvent
}
var _ logo.LogoGraph = episode{}

var event = episode{
    Event: logo.OfficeHoursEvent{
        Status: "EventProposed",
        StartDate: "2025-11-01T00:00:00Z",
        EndDate: "2025-11-01T01:00:00Z",
    },
}

func(e episode) Cid() string {
    return e.Event.Compose(e.Event).Cid()
}

func(e episode) renderOpts() map[string]any {
    return map[string]any{
        "dev":      map[string]any{}, // REVIEW: chainIds are used to provide a chain-level opts namespace
        "labsnet1": map[string]any{},
    }
}

func(e episode) Image() string {
    return e.Event.Image()
}

func(e episode) DataUrl() string {
    return e.Event.DataUrl()
}

func(e episode) Thumbnail() string {
    return e.Event.Thumbnail()
}

func(e episode) SVG() string {
    return e.Event.SVG()
}

func(e episode) JsonLD() eve.JsonLDMap {
    return e.Event.Compose(e.Event)
}