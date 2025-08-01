package gnolandlaunch

// join waitlist for event
func JoinWaitlist() {
	app.JoinWaitlist()
}

func RenderCalendar(path string) string {
	return app.RenderCalendar(path)
}

func Render(path string) (out string) {
	return app.Render(path)
}