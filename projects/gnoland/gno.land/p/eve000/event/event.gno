package event

import (
	"strconv"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/agenda"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
	"gno.land/p/eve000/event/speaker"
)

var f = ufmt.Sprintf

type Storage struct {
	Sessions  *avl.Tree
	Speakers  *avl.Tree
	Locations *avl.Tree
}

type Event struct {
	Name        string
	Location    *location.Location
	StartDate   time.Time
	EndDate     time.Time
	Description string
	Sessions    []*session.Session
	renderOpts  *component.RenderOpts
	storage     *Storage
}

var _ component.Component = (*Event)(nil)

func (evt *Event) SetEventName(name string) {
	evt.Name = name
}

func (evt *Event) SetEventLocation(loc *location.Location) {
	evt.Location = loc
}

func (evt *Event) SetEventStartDate(startDate time.Time) {
	evt.StartDate = startDate
}

func (evt *Event) SetEventEndDate(endDate time.Time) {
	evt.EndDate = endDate
}

func (evt *Event) SetEventDescription(description string) {
	evt.Description = description
}

func (evt *Event) SetSessions(sessions []*session.Session) {
	evt.Sessions = sessions
}

func (evt *Event) AddSpeaker(s *speaker.Speaker) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Speakers == nil {
		evt.storage.Speakers = &avl.Tree{}
	}
	id := Pad3(strconv.Itoa(evt.storage.Speakers.Size()))
	evt.storage.Speakers.Set(AvlKey("speaker", id), s)
}

func (evt *Event) AddLocation(loc *location.Location) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Locations == nil {
		evt.storage.Locations = &avl.Tree{}
	}
	id := Pad3(strconv.Itoa(evt.storage.Locations.Size()))
	evt.storage.Locations.Set(AvlKey("location", id), loc)
}

func (evt *Event) AddSession(sess *session.Session) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Sessions == nil {
		evt.storage.Sessions = &avl.Tree{}
	}
	id := Pad3(strconv.Itoa(evt.storage.Sessions.Size()))
	evt.storage.Sessions.Set(AvlKey("session", id), sess)
}

func (event *Event) GetSpeaker(id string) *speaker.Speaker {
	s, ok := event.storage.Speakers.Get(AvlKey("speaker", id))
	if !ok {
		panic("speaker not found: id=" + id)
	}
	return s.(*speaker.Speaker)
}

func (event *Event) GetLocation(id string) *location.Location {
	l, ok := event.storage.Locations.Get(AvlKey("location", id))
	if !ok {
		panic("location not found: id=" + id)
	}
	return l.(*location.Location)
}

func (event *Event) GetSession(id string) *session.Session {
	s, ok := event.storage.Sessions.Get(AvlKey("session", id))
	if !ok {
		panic("session not found: id=" + id)
	}
	return s.(*session.Session)
}

func (evt *Event) Agenda() *agenda.Agenda {
	a := &agenda.Agenda{
		Name:        evt.Name,
		Location:    evt.Location,
		StartDate:   evt.StartDate,
		EndDate:     evt.EndDate,
		Description: evt.Description,
		Sessions:    evt.Sessions,
	}
	a.SetRenderOpts(evt.renderOpts)
	return a
}

func Pad3(s string) string {
	for len(s) < 3 {
		s = "0" + s
	}
	return s
}

// build a key for the AVL tree like "event:123" "speaker:456" or "location:789"
func AvlKey(label string, id string) string {
	return Pad3(id)
}

// Event may not be a component (yet!) but it is where the render opts are stored.
func (evt *Event) RenderOpts() *component.RenderOpts {
	return evt.renderOpts
}

func (evt *Event) SetRenderOpts(opts *component.RenderOpts) {
	evt.renderOpts = opts
}

func (evt *Event) ToAnchor() string {
	return component.StringToAnchor(evt.Name)
}

func (evt *Event) ToMarkdown() string {
	// REVIEW: will keynote block be rendered properly
	return evt.Agenda().ToMarkdown()
}

func (evt *Event) ToSvgDataUrl() string {
	return evt.Agenda().ToSvgDataUrl()
}

func (evt *Event) ToSVG() string {
	return evt.Agenda().ToSVG()
}

func (evt *Event) ToJson() string {
	return `{
    "@context": "https://schema.org",
    "@type": "Event",
    "name": "` + ufmt.Sprintf("%s", evt.Name) + `",
    "startDate": "` + ufmt.Sprintf("%s", evt.StartDate.Format("2006-01-02T15:04:05-07:00")) + `",
    "endDate": "` + ufmt.Sprintf("%s", evt.EndDate.Format("2006-01-02T15:04:05-07:00")) + `",
    "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode",
    "eventStatus": "https://schema.org/EventScheduled",
    "location": {
        "@type": "Place",
        "name": "` + ufmt.Sprintf("%s", evt.Location.Name) + `"
    },
    "image": [],
    "description": "` + ufmt.Sprintf("%s", evt.Description) + `"
	}`
}
