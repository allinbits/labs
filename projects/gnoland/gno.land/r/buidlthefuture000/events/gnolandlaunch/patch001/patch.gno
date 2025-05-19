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

func init() {
	newDescription := "GopherCon is a conference dedicated to the Go programming language, promoting its use," +
		" fostering an inclusive community, and providing education to developers."

	// event.ToggleOpts("schedule")

	// event.SetContent("map", "\n\n{Map}")

	event.SetSpeakerName(0, "Alice Johnston") // overwrite speaker name adds a "t" to the last name
	event.SetLocationName(0, "Room A-1")      // overwrite location name

	eventId := event.LiveEventId()
	event.SetEventDescription(eventId, newDescription)             // overwrite description - removes "is an annual conference" and adds "is a conference"
	newSessionId := event.AddEventSession(eventId, "1h30m", "30m") // add a new session with 30m delay
	event.SetEventSessionSpeaker(0, newSessionId, eventId)         // set the speaker for the new session to Alice Johnston

	event.SetPatchLevel(1) // set the patch level to 1

	// event.Publish(event.AgendaMarkdown(eventId)) // set final version (hides live event)
	// event.Destroy("Bye forever")  // re-create registry - deletes all events

	e := event.AddEvent(
		"Build The Future 2025",
		"Gnowhere",
		"2025-05-01", "2025-05-01",
		"Build The Future is a conference dedicated to enriching the Gno Land Ecosystem.",
	)
	s := event.AddEventSession(e, "2h00m", "9h")
	event.SetEventSessionTitle(e, s, "Building the Future of Gno Land")
	event.SetEventSessionDescription(e, s, "Join us for a deep dive into the future of Gno Land and its ecosystem.")

	event.SetEventSpeakerName(e, s, "Daniel Johnston")
	event.SetEventSpeakerBiography(e, s, "Daniel Johnston is a Gno Land developer and contributor to the Gno Land Ecosystem.")
	event.SetEventSpeakerAffiliation(e, s, "Gno Land")
	event.AddSpeakerTags(e, s, "Gno Land", "Developer", "Contributor")

	event.SetEventLocationName(e, s, "Room A-1")
	event.SetEventLocationCoordinates(e, s, "40.7128, -74.0060")
	event.SetEventLocationDescription(e, s, "Room A-1 is a conference room located in the Gno Land headquarters.")

	event.AddSessionTags(e, s, "Gno Land", "Conference", "Future")

	event.SetContent("keynote", "### Keynote Speaker: Jae Kwon\nJoin us for an inspiring keynote at the Build The Future Meeting featuring Jae Kwon,\nvisionary blockchain pioneer and creator of Gnoland.")
	event.SetLiveEvent(e)
}

func Render(_ string) string {
	return releaseNotes
}
