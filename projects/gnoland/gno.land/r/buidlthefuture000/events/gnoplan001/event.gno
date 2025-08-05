package gnoplan

import (
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

func init() {
	renderOpts := map[string]interface{}{
		"dev": map[string]interface{}{
			"Speaker":      struct{}{},
			"SvgFooter":    struct{}{},
			"CalendarHost": "webcal://127.0.0.1:8080",
		},
	}
	app.RegisterEvent(gnolandlaunch, renderOpts)
}

// banner content block is shown in the top section of the event page
var banner = eve.Content{
	Published: true,
	Markdown: "\n\n#### Status: Seeking Stakeholders for Planning \n\n" +
		eve.TxlinkButton("Join Beta", "JoinBeta"),
}

var locations = map[string]*eve.Location{
	"gnowhere": {
		Name:        "Gnowhere",
		Description: "",
	},
	"discord": {
		Name:        "Discord ",
		Description: "",
	},
}

var speakerBios = map[string]*eve.Speaker{
	"mason": {
		Name:        "Mason",
		Biography:   "Nathan is a member of AIBLabs working on Eve event platform.",
		Affiliation: "allinbits.com",
		PictureURL:  "",
	},
	"nathan": {
		Name:        "Nathan",
		Biography:   "Nathan is a member of AIBLabs working on Eve event platform.",
		Affiliation: "allinbits.com",
		PictureURL:  "",
	},
	"matt": {
		Name:        "Matt",
		Biography:   "Matt is a member of AIBLabs working on Eve event platform.",
		Affiliation: "allinbits.com",
		PictureURL:  "https://stackdump.com/profile.jpg",
		Address:     "g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz",
	},
}

var sessions = map[string]*eve.Session{
	"kickoff": {
		Title:       "Test our Tools: Gno.land and Gnoland",
		Description: "This is a kickoff of an internal beta.",
		Speaker:     speakerBios["matt"],
		StartTime:   time.Date(2025, 7, 17, 13, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 7, 17, 13, 30, 0, 0, time.UTC),
		Location:    locations["gnowhere"],
	},
	"retro": {
		Title:       "Review and Retrospective",
		Description: "Let's review the beta and gather feedback.",
		Speaker:     speakerBios["mason"],
		StartTime:   time.Date(2025, 8, 29, 13, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 8, 29, 13, 30, 0, 0, time.UTC),
		Location:    locations["gnowhere"],
	},
}

var gnolandlaunch = &event.Event{
	Name:           "Gnoland Launch Preplanning",
	Location:       locations["gnowhere"],
	Status:         eve.EventScheduled,
	AttendanceMode: eve.OnlineEventAttendanceMode,
	StartDate:      time.Date(2025, 7, 14, 0, 0, 0, 0, time.UTC),
	EndDate:        time.Date(2025, 8, 29, 0, 0, 0, 0, time.UTC),
	Description:    "Join this event to become a beta tester for Gnoland, help us think about planning the launch, and provide feedback on the platform. \n\n This is a pre-planning event to gather ideas and feedback from the community.",
	Sessions: []*eve.Session{
		sessions["kickoff"],
		sessions["retro"],
	},
}
