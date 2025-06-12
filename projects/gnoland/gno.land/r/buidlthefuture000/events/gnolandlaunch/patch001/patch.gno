package patch

import (
	event "gno.land/r/buidlthefuture000/events/gnolandlaunch"
)

const releaseNotes = `
### Patch 001
- Speaker name updated
- Description updated
- Location name updated
- New session added
- Patch level set to 1
- New event added
- New session added to new event
- New speaker added to new session
- New location added to new session
`

// REVIEW: leaving patch 001 in the codebase for now as a reference
func init() {
	newDescription := "GopherCon is a conference dedicated to the Go programming language, promoting its use," +
		" fostering an inclusive community, and providing education to developers."

	// event.ToggleOpts("schedule")

	// event.SetContent("map", "\n\n{Map}")

	event.SetSpeakerName(2, "Alice Johnston") // overwrite speaker name adds a "t" to the last name
	event.SetLocationName(2, "Room A-1")      // overwrite location name

	eventId := event.LiveEventId()
	event.SetEventDescription(eventId, newDescription)             // overwrite description - removes "is an annual conference" and adds "is a conference"
	newSessionId := event.AddEventSession(eventId, "1h30m", "30m") // add a new session with 30m delay
	event.SetEventSessionSpeaker(0, newSessionId, eventId)         // set the speaker for the new session to Alice Johnston
	event.SetEventSessionDescription(0, 1, "Learn practical use cases for Go generics to simplify and enhance your code!")

	event.SetPatchLevel(1) // set the patch level to 1
}

func Render(_ string) string {
	return releaseNotes
}
