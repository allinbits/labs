package officehours

import (
	"gno.land/p/eve000/event"
)

var opts map[string]string = map[string]string{
    "Status":      "EventScheduled",
    "StartDate":   "2025-11-01T10:20:00Z",
    "EndDate":     "2025-11-01T11:20:00Z",
    "Title":       "AibLabs Office Hours",
    "Description": "AibLabs Office Hours: Join us for open discussion.",
}

var app = event.NewCalendar(opts)

func Render(path string) string { return app.Render(path) }
