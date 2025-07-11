package gnolandlaunch

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
        "Svg":       struct{}{},
        "Schedule":  struct{}{},
    }
	app.RegisterEvent(gnolandlaunch, renderOpts)
}

// banner content block is shown in the top section of the event page
var banner = &component.Content{
	Published: true,
	Markdown: "\n\n#### Status: Accepting Session Proposals\n #### expected dates: Aug 2025 \n\n" +
		component.TxlinkButton("Join Waitlist", "JoinWaitlist"),
}

var locations = map[string]*location.Location{
	"gnowhere": {
		Name:        "Gnowhere",
		Description: "",
	},
	"room-a1": {
		Name:        "Room A1",
		Description: "Main hall for Go Generics talk",
	},
	"room-b2": {
		Name:        "Room B2",
		Description: "Secondary hall for Concurrency Patterns",
	},
	"room-c3": {
		Name:        "Room C3",
		Description: "Workshop room for High-Performance APIs",
	},
}

var speakerBios = map[string]*speaker.Speaker{
	"jae": {
		Name:        "Jae Kwon",
		Biography:   "Jae Kwon is the creator of Gno.land and co-founder of Cosmos, pioneering decentralized systems built on logic and sovereignty.",
		Affiliation: "",
		PictureURL:  "",
	},
	"alice": {
		Name:        "Alice Johnson",
		Biography:   "Alice is a Senior Go engineer who has evangelized Go generics across multiple open‐source projects.",
		Affiliation: "Acme Corp",
		PictureURL:  "",
	},
	"bob": {
		Name:        "Bob Smith",
		Biography:   "Bob is a distributed systems expert focusing on concurrency models and real‐world Go applications.",
		Affiliation: "Foo Systems",
		PictureURL:  "",
	},
	"carol": {
		Name:        "Carol Martinez",
		Biography:   "Carol leads API performance teams and has built several high‐throughput Go services in production.",
		Affiliation: "BarTech",
		PictureURL:  "",
	},
}

var Sessions = map[string]*session.Session{
	"keynote": {
		Title:       "The Road to Web7",
		Description: "Join us for an inspiring keynote at the Build The Future Meeting featuring Jae Kwon, visionary blockchain pioneer and creator of Gno.land.",
		Speaker:     speakerBios["jae"],
		StartTime:   time.Date(2025, 6, 25, 10, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 6, 25, 11, 30, 0, 0, time.UTC),
		Location:    locations["gnowhere"],
	},

	"generics": {
		Title:       "Generics in Action: Simplifying Go Code",
		Description: "Learn practical use cases for Go generics to simplify and enhance your code.",
		Speaker:     speakerBios["alice"],
		StartTime:   time.Date(2025, 6, 26, 10, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 6, 26, 11, 30, 0, 0, time.UTC),
		Location:    locations["room-a1"],
	},

	"concurrency": {
		Title:       "Concurrency Patterns in Real‐World Applications",
		Description: "A deep dive into concurrency patterns to efficiently handle complex workflows.",
		Speaker:     speakerBios["bob"],
		StartTime:   time.Date(2025, 6, 27, 13, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 6, 27, 14, 30, 0, 0, time.UTC),
		Location:    locations["room-b2"],
	},

	"apis": {
		Title:       "Building High‐Performance APIs with Go",
		Description: "Techniques and best practices for building scalable and performant APIs.",
		Speaker:     speakerBios["carol"],
		StartTime:   time.Date(2025, 6, 28, 15, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 6, 28, 16, 30, 0, 0, time.UTC),
		Location:    locations["room-c3"],
	},
}

var gnolandlaunch = &event.Event{
	Name:     "Gnoland Launch",
	Location: locations["gnowhere"],
	// StartDate:   time.Date(2025, 7, 25, 0, 0, 0, 0, time.UTC),
	// EndDate:     time.Date(2025, 7, 25, 23, 59, 59, 0, time.UTC),
	Description: "Join us as Gno.land creator Jae Kwon shares his vision of a logic-first internet—where code is law and realms are the new web.",
	Sessions:    []*session.Session{
		// TODO: add finalized sessions here
		// Sessions["keynote"],
		// Sessions["generics"],
		// Sessions["concurrency"],
		// Sessions["apis"],
	},
}
