package officehours

import (
    "strings"
	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

type calendar struct {
	Title string
	Dates avl.Tree // key: date string, value: Schedule
}

var eventCalendar = calendar{
	Title: "Gno.land Office Hours Calendar",
	Dates: *avl.NewTree(),
}

var _ LogoGraph   = eventCalendar
var _ Projectable = eventCalendar

func init() {
    Register(eventCalendar, func(rec Record) {
        date := eventCalendar.Event().Date()
        eventCalendar.Dates.Set(date, eventCalendar.Event())
    })
}

func (c calendar) Event(path ...string) Schedule {
    // FIXME read from c.Dates based on path or current date
	return Schedule{
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

func (calendar) RenderTable() string {
    var sb strings.Builder
    sb.WriteString(OfficeHours.Heading())

    eventCalendar.Dates.IterateByOffset(0, eventCalendar.Dates.Size(), func(key string, value interface{}) bool {
        if schedule, ok := value.(Schedule); ok {
            sb.WriteString(OfficeHours.Row(schedule)) // FIXME: CID is only populated in Events - pull data from Registry
        }
        return false
    })

    return sb.String()
}
