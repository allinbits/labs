package gnoplan

import (
	"gno.land/p/eve000/event"
)

func LiveEvent() *event.Event {
	return app.LiveEvent()
}

// JoinBeta allows users to join the beta program for the Gno.land launch event.
func JoinBeta() {
	app.JoinWaitlist() // waitlist is re-used for beta program
}

func RenderCalendar(path string) string {
	return LiveEvent().RenderCalendar(path)
}
