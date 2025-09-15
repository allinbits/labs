package officehours

import (
	eve "gno.land/p/eve000/event/component"
	logo "gno.land/r/labs000/logoverse"
)


type episode struct {}

var event = episode{}

var _ logo.LogoGraph = episode{}
var _ logo.Projectable = episode{}

var cid = logo.Register(event)

func Render(path string) string {
    if path == "" {
        path = "?cid=" + cid
    }
    return logo.Render(path)
}

func (episode) Event() logo.OfficeHoursEvent {
    evt := logo.OfficeHoursEvent{
        Status: "EventProposed",
        StartDate: "2025-11-01T00:00:00Z",
        EndDate: "2025-11-01T01:00:00Z",
        Description: "This is a description of the event.",
        Location: "Gnowhere",
    }
    return evt
}

func(e episode) Cid() string {
    return logo.OfficeHours.Compose(event.Event()).Cid()
}

func(e episode) Image() string {
    return logo.OfficeHours.Image()
}

func(e episode) DataUrl() string {
    return logo.OfficeHours.DataUrl()
}

func(e episode) Thumbnail() string {
    return logo.OfficeHours.Thumbnail()
}

func(e episode) SVG() string {
    return logo.OfficeHours.SVG()
}

func(e episode) JsonLD() eve.JsonLDMap {
    return logo.OfficeHours.Compose(e.Event())
}

func(e episode) FromPath(path string) interface{} {
    return logo.OfficeHours.FromPath(path)
}

func(e episode) ToPath(obj ...interface{}) string {
    return logo.OfficeHours.ToPath(obj...)
}

func(e episode) Compose(obj ...interface{}) eve.JsonLDMap {
    return logo.OfficeHours.Compose(obj...)
}