package gnoplan

import (
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

func init() {
	evt.SetRenderOpts(map[string]interface{}{
		"dev": map[string]interface{}{
			"SvgFooter":       struct{}{},
			"CalendarHost": "webcal://127.0.0.1:8080",
			"CalendarFile":    "http://127.0.0.1:8080",
		},
		"labsnet1": map[string]interface{}{
			"SvgFooter":       struct{}{},
			"CalendarHost": "webcal://gnocal.aiblabs.net",
			"CalendarFile":    "https://gnocal.aiblabs.net",
		},
	})
}

var banner = eve.Content{
	Published: true,
	Markdown: " A meeting that never happens - this could definitely just be an e-mail.",
}

var evt = &event.Event{
	Name:           "Tomorrow's just a day away",
	Status:         eve.EventPostponed,
	AttendanceMode: eve.OnlineEventAttendanceMode,
	Description:    "Add a calendar event that is always tomorrow at 1pm UTC.",
}

func Render(path string) string {
	return evt.RenderPage(path, banner)
}

func RenderCalendar(path string) string {
	return evt.Render(path, eve.IcsCalendarFile)
}

func tomorrow() *time.Time {
    t := time.Now().Add(24 * time.Hour)
    return &t
}

func utc1pm() time.Time {
    return time.Date(tomorrow().Year(), tomorrow().Month(), tomorrow().Day(), 13, 0, 0, 0, time.UTC)
}

func utc2pm() time.Time {
    return time.Date(tomorrow().Year(), tomorrow().Month(), tomorrow().Day(), 14, 0, 0, 0, time.UTC)
}

var sessions = map[string]*eve.Session{
	"tomorrow": {
		Title:       "Let's meet tomorrow",
		Description: "This date is always tomorrow at 1pm UTC",
		StartTime:   utc1pm(),
		EndTime:     utc2pm(),
	},
}
