package gnolandlaunch

import (
    "gno.land/p/eve000/event/component"
)

// join waitlist for event
func JoinWaitlist() {
	app.JoinWaitlist()
}

func RenderCalendar(path string) string {
	return app.LiveEvent().Render(path, component.IcsCalendarFile)
}

func Render(path string) (out string) {
	return app.Render(path) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}
