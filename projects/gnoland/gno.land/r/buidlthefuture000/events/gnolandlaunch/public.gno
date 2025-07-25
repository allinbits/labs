package gnolandlaunch

// join waitlist for event
func JoinWaitlist() {
	app.JoinWaitlist()
}

func RenderCalendar(path string) string {
	return app.LiveEvent().RenderCalendar(path)
}
