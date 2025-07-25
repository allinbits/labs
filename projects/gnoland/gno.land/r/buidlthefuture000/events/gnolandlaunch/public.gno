package gnolandlaunch

import (
	"gno.land/p/eve000/event"
)

func LiveEvent() *event.Event {
	return app.LiveEvent()
}

func JoinWaitlist() {
	app.JoinWaitlist()
}

func RenderCalendar(path string) string {
	return LiveEvent().RenderCalendar(path)
}
