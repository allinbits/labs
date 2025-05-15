package event

import (
	"time"

	"gno.land/p/eve/event"
	"gno.land/p/eve/event/location"
	"gno.land/p/eve/event/session"
	"gno.land/p/eve/event/speaker"
)

var locations = map[string]*location.Location{
	"room-a1": {
		Name:        "Room A1",
		Description: "First Level - Auditorium",
	},
	"room-b2": {
		Name:        "Room B2",
		Description: "Second Level - Conference Hall",
	},
	"room-c3": {
		Name:        "Room C3",
		Description: "Third Level - Meeting Room",
	},
}

var speakers = map[string]*speaker.Speaker{
	"alice": {
		Name:        "Alice Johnson",
		Biography:   "Senior Software Engineer and contributor to the Go open-source project.",
		Affiliation: "Google",
		PictureURL:  "https://avatars.githubusercontent.com/u/243500?s=400&u=fc288b7371b31b282885fd246ad09c168b96a6dc&v=4",
	},
	"bob": {
		Name:        "Bob Smith",
		Biography:   "CTO at Gopher Labs, author of 'Mastering Concurrency in Go'",
		Affiliation: "Gopher Labs",
		PictureURL:  "https://avatars.githubusercontent.com/u/243500?s=400&u=fc288b7371b31b282885fd246ad09c168b96a6dc&v=4",
	},
	"carol": {
		Name:        "Carol Davis",
		Biography:   "Backend Engineer at APIify, experienced in distributed systems and API design.",
		Affiliation: "APIify",
		PictureURL:  "https://avatars.githubusercontent.com/u/243500?s=400&u=fc288b7371b31b282885fd246ad09c168b96a6dc&v=4",
	},
}

var sessions = map[string]*session.Session{
	"generics": {
		Title:       "Generics in Action: Simplifying Go Code",
		Description: "Learn practical use cases for Go generics to simplify and enhance your code.",
		Speaker:     speakers["alice"],
		StartTime:   time.Date(2025, 8, 26, 10, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 8, 26, 11, 30, 0, 0, time.UTC),
		Location:    locations["room-a1"],
	},
	"concurrency": {
		Title:       "Concurrency Patterns in Real-World Applications",
		Description: "A deep dive into concurrency patterns to efficiently handle complex workflows.",
		Speaker:     speakers["bob"],
		StartTime:   time.Date(2025, 8, 27, 13, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 8, 27, 14, 30, 0, 0, time.UTC),
		Location:    locations["room-b2"],
	},
	"apis": {
		Title:       "Building High-Performance APIs with Go",
		Description: "Techniques and best practices for building scalable and performant APIs.",
		Speaker:     speakers["carol"],
		StartTime:   time.Date(2025, 8, 28, 15, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 8, 28, 16, 30, 0, 0, time.UTC),
		Location:    locations["room-c3"],
	},
}

var gopherCon2025 = &event.Event{
	Name: "GopherCon 2025",
	Location: &location.Location{
		Name: "North Javits Center, New York City, NY",
	},
	StartDate: time.Date(2025, 8, 26, 0, 0, 0, 0, time.UTC),
	EndDate:   time.Date(2025, 8, 28, 0, 0, 0, 0, time.UTC),
	Description: "GopherCon is an annual conference dedicated to the Go programming language, \n" +
		"promoting its use, fostering an inclusive community, and providing education to developers.",
	Sessions: []*session.Session{
		sessions["generics"],
		sessions["concurrency"],
		sessions["apis"],
	},
}
