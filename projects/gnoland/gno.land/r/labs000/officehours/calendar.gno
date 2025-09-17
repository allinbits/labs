package officehours

import (
    "strings"
	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

type calendar struct {
	Title string
	Dates *avl.Tree // key: date string, value: Schedule
}

var eventCalendar = calendar{
	Title: "Gno.land Office Hours Calendar",
	Dates: avl.NewTree(),
}

var _ LogoGraph   = eventCalendar
var _ Projectable = eventCalendar

func init() {
    Register(eventCalendar, func(rec Record) {
        cal := rec.Object.(calendar)
        cal.Dates.Set(rec.Cid, cal.Event())
    })
}

func (c calendar) Event(path ...string) Schedule {
	return Schedule{
		Status:      "EventPlanned",
		StartDate:   OhrSchedule.StartDate,
		EndDate:     OhrSchedule.EndDate,
		Title:       OhrSchedule.Title,
		Description: OhrSchedule.Description,
		Location:    "Gnowhere",
	}
}

func (calendar) Cid(path ...string) string { return eventCalendar.JsonLD(path...).Cid() }
func (calendar) Image(path ...string) string     { return OhrSchedule.Image(path...) }
func (calendar) DataUrl(path ...string) string   { return OhrSchedule.DataUrl(path...) }
func (calendar) Thumbnail(path ...string) string { return OhrSchedule.Thumbnail(path...) }
func (calendar) SVG(path ...string) string       { return OhrSchedule.SVG(path...) }
func (calendar) JsonLD(path ...string) eve.JsonLDMap { return OhrSchedule.JsonLD(path...) }

// ---- Projectable passthrough ----

func (calendar) FromPath(path ...string) interface{}   { return OhrSchedule.FromPath(path...) }
func (calendar) ToPath(obj ...interface{}) string      { return OhrSchedule.ToPath(obj...) }
func (calendar) Compose(obj ...interface{}) interface{} { return OhrSchedule.Coalesce(eventCalendar.Event(), obj) }

func (calendar) RenderTable() string {
    if calendarRegistry.Size() == 0 {
        return "No calendars registered."
    }

    var sb strings.Builder
    sb.WriteString(eventCalendar.Heading())

    calendarRegistry.IterateByOffset(0, calendarRegistry.Size(), func(key string, value any) bool {
        rec, ok := value.(Record)
        if !ok {
            return false // skip non-Record entries
        }

        if cal, isCalendar := rec.Object.(calendar); isCalendar {
            sb.WriteString(eventCalendar.Row(cal))
        }
        return false
    })

    return sb.String()
}

func (calendar) Coalesce(obj ...interface{}) calendar {
    if len(obj) == 0 || obj[0] == nil {
        return eventCalendar
    }
    if c, ok := obj[0].(calendar); ok {
        return c
    }
    panic("invalid calendar object")
}

func (calendar) Heading() string {
    return "| Calendar | \n" + "| ------------- |\n"
}

func (calendar) Row(obj calendar) string {
    return "| [" + obj.Title + "](./officehours?cal=" + obj.Cid() + ") | "
}
