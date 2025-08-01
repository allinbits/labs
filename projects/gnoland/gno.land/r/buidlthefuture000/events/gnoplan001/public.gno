package gnoplan

// JoinBeta allows users to join the beta program for the Gno.land launch event.
func JoinBeta() {
	app.JoinWaitlist() // waitlist is re-used for beta program
}

func RenderCalendar(path string) string {
	return app.LiveEvent().Flyer().RenderCalendar(path)
}

func Render(path string) (out string) {
	return app.Render(path) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}
