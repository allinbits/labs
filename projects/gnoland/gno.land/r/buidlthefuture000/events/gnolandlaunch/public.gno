package gnolandlaunch

// join waitlist for event
func JoinWaitlist() {
	app.JoinWaitlist()
}

func RenderCalendar(path string) string {
	return app.LiveEvent().RenderCalendar(path)
}

func Render(path string) (out string) {
	return app.Render(path) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}
