package officehours

import (
	eve "gno.land/p/eve000/event/component"
)

type calendar struct {
	title string
}

var evt = calendar{}

// FIXME:
// var cid = Register(evt)
var cid string = "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku" // TODO: replace with real cid

func (calendar) Event(path ...string) OfficeHoursObj {
	// FIXME build from path
	return OfficeHoursObj{
		Status:      "EventPlanned",
		StartDate:   "2025-11-01T00:00:00Z",
		EndDate:     "2025-11-01T01:00:00Z",
		Description: "Propose Event Here",
		Location:    "Gnowhere",
	}
}

func (calendar) Cid(path ...string) string {
	return OfficeHours.Compose(evt.Event(path...)).(LogoGraph).JsonLD().Cid()
}

func (calendar) Image(path ...string) string {
	return OfficeHours.Image(path...)
}

func (calendar) DataUrl(path ...string) string {
	return OfficeHours.DataUrl(path...)
}

func (calendar) Thumbnail(path ...string) string {
	// REVIEW: thumbnail should be the SVG version of the flyer
	return OfficeHours.Thumbnail(path...)
}

func (calendar) SVG(path ...string) string {
	return OfficeHours.SVG(path...)
}

func (calendar) JsonLD(path ...string) eve.JsonLDMap {
	return OfficeHours.Compose(evt.Event(path...)).(LogoGraph).JsonLD()
}

func (calendar) FromPath(path ...string) interface{} {
	return OfficeHours.FromPath(path...)
}

func (calendar) ToPath(obj ...interface{}) string {
	return OfficeHours.ToPath(obj...)
}

func (calendar) Compose(obj ...interface{}) eve.JsonLDMap {
	return OfficeHours.Compose(evt.Event()).(LogoGraph).JsonLD()
}
