package onsite

import (
	"time"

	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
	"gno.land/p/eve000/event/speaker"
)

func init() {
	renderOpts := map[string]interface{}{
		"Location": struct{}{},
	}
	app.RegisterEvent(gnolandlaunch, renderOpts)
}

// banner content block is shown in the top section of the event page
var banner = component.Content{
	Published: true,
	Markdown:  "\n\n#### Status: Pre-planning",
}

var locations = map[string]*location.Location{
	"null": {
		Name:        "Null Island",
		Coordinates: "0.0, 0.0",
		Description: "*not an actual Island [![Null Island coords: 0, 0](https://cdn.jsdelivr.net/gh/BUIDLTHEFUTURE/events@main/static/img/null_island.png)](https://en.wikipedia.org/wiki/Null_Island)",
	},
	"atx": {
		Name:        "Austin, Texas",
		Address:     "500 E Cesar Chavez St, Austin, TX 78701",
		Coordinates: "30.2672, -97.7431",
		Description: "Join us in the heart of Texas for an unforgettable event!",
	},
}

var sessions = map[string]*session.Session{
	"kickoff": {
		Title:       "A Visit To Null Island",
		Description: "Welcome to nowhere - there is nothing here, but we can still have a good time!",
		Speaker:     &speaker.Speaker{},
		StartTime:   time.Date(2025, 7, 17, 13, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 7, 17, 13, 30, 0, 0, time.UTC),
		Location:    locations["null"],
	},
	"summit": {
		Title:       "Summit in Austin",
		Description: "Join us for a summit in Austin, Texas to discuss the future of Gnoland and how we can build it together.",
		Speaker:     &speaker.Speaker{},
		StartTime:   time.Date(2025, 7, 18, 10, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 7, 18, 17, 0, 0, 0, time.UTC),
		Location:    locations["atx"],
	},
}

var gnolandlaunch = &event.Event{
	Name:           "IRL Meetup",
	Location:       locations["gnowhere"],
	StartDate:      time.Date(2025, 7, 14, 0, 0, 0, 0, time.UTC),
	EndDate:        time.Date(2025, 8, 29, 0, 0, 0, 0, time.UTC),
	Status:         component.EventMovedOnline, // it was planned as an IRL event example, but it was moved online ;-P
	AttendanceMode: component.OfflineEventAttendanceMode,
	Description:    "Join this event to become a beta tester for Gnoland, help us think about planning the launch, and provide feedback on the platform. \n\n This is a pre-planning event to gather ideas and feedback from the community.",
	Sessions: []*session.Session{
		sessions["kickoff"],
		sessions["summit"],
	},
}
