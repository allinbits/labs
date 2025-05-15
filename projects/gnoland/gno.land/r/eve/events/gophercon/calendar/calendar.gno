package calendar

import (
	"time"

	"gno.land/p/eve/event/calendar"
	"gno.land/p/eve/event/location"
)

var calendarEvents []calendar.CalendarEvent

func init() {
	calendarEvents = []calendar.CalendarEvent{
		{
			Name:        "New Year's Day",
			Date:        time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
			Description: "Celebration of the new year.",
		},
		{
			Name:        "Valentine's Day",
			Date:        time.Date(2025, 2, 14, 0, 0, 0, 0, time.UTC),
			Description: "A day to celebrate love and affection.",
		},
		{
			Name:        "St. Patrick's Day",
			Date:        time.Date(2025, 3, 17, 0, 0, 0, 0, time.UTC),
			Description: "Celebration of Irish culture and heritage.",
		},
		{
			Name:        "Independence Day",
			Date:        time.Date(2025, 7, 4, 0, 0, 0, 0, time.UTC),
			Description: "Celebration of independence.",
		},
	}
	_ = location.Location{}
}

func Render(path string) string {
	return calendar.RenderCalendar(path, calendarEvents)
}
