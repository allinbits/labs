package officehours

import (
	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

type calendar struct {
	Title string
	Dates avl.Tree // key: date string, value: OfficeHoursObj
}

var eventCalendar = calendar{
	Title: "Gno.land Office Hours Calendar",
	Dates: *avl.NewTree(),
}

var _ LogoGraph   = eventCalendar
var _ Projectable = eventCalendar

var cid = ""

func init() {
    cid = Register(eventCalendar)
    // TODO: populate dates when children are added
    //eventCalendar.Dates.Set(cid, counter.Count)
}

func (c calendar) Event(path ...string) OfficeHoursObj {
	return OfficeHoursObj{
		Status:      "EventPlanned",
		StartDate:   "2025-11-01T00:00:00Z",
		EndDate:     "2025-11-01T01:00:00Z",
		Description: c.Title,
		Location:    "Gnowhere",
	}
}

func (calendar) Cid(path ...string) string {
	// Better: compute from JsonLD for stability
	return eventCalendar.JsonLD(path...).Cid()
}

func (calendar) Image(path ...string) string     { return OfficeHours.Image(path...) }
func (calendar) DataUrl(path ...string) string   { return OfficeHours.DataUrl(path...) }
func (calendar) Thumbnail(path ...string) string { return OfficeHours.Thumbnail(path...) }
func (calendar) SVG(path ...string) string       { return OfficeHours.SVG(path...) }
func (calendar) JsonLD(path ...string) eve.JsonLDMap { return OfficeHours.JsonLD(path...) }

// ---- Projectable passthrough ----

func (calendar) FromPath(path ...string) interface{}   { return OfficeHours.FromPath(path...) }
func (calendar) ToPath(obj ...interface{}) string      { return OfficeHours.ToPath(obj...) }
func (calendar) Compose(obj ...interface{}) interface{} { return OfficeHours.Coalesce(eventCalendar.Event(), obj) }
