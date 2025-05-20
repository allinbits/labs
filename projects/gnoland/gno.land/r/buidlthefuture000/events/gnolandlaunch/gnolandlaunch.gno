package event

import (
	"time"

	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
	"gno.land/p/eve000/event/speaker"
)

var locations = map[string]*location.Location{
	"gnowhere": {
		Name:        "Gnowhere",
		Description: "",
	},
}

var speakerBios = map[string]*speaker.Speaker{
	"jae": {
		Name:        "Jae Kwon",
		Biography:   "Jae Kwon is the creator of Gno.land and co-founder of Cosmos, pioneering decentralized systems built on logic and sovereignty.",
		Affiliation: "",
		PictureURL:  "",
	},
}

var sessions = map[string]*session.Session{
	"keynote": {
		Title:       "The Road to Web7",
		Description: "Join us for an inspiring keynote at the Build The Future Meeting featuring Jae Kwon, visionary blockchain pioneer and creator of Gnoland.",
		Speaker:     speakerBios["jae"],
		StartTime:   time.Date(2025, 8, 1, 10, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 8, 1, 11, 30, 0, 0, time.UTC),
		Location:    locations["gnowhere"],
	},
}

var gnoLandLaunchEvent = &event.Event{
	Name: "Gnoland Launch",
	Location: &location.Location{
		Name: "Welcome to the Logoverse",
	},
	StartDate: time.Date(2025, 8, 1, 0, 0, 0, 0, time.UTC),
	EndDate:   time.Date(2025, 8, 1, 0, 0, 0, 0, time.UTC),
	Description: "Join us as Gno.land creator Jae Kwon shares his vision of a logic-first internet—where code is law and realms are the new web.",
	Sessions: []*session.Session{
		sessions["keynote"],
	},
}
