package event

import (
	"std"
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

type Api interface {
	AddOrganizer(addr std.Address)
	AddProposer(addr, sender std.Address)
	AddReviewer(addr, sender std.Address)
	AddSpeaker(addr std.Address)
	AdminRemoveRole(role string, addr std.Address)
	AdminSetRole(role string, addr std.Address)
	AssertAtLeastRole(role string, sender std.Address)
	Destroy(markdown string)
	HasRole(role string, addr std.Address) bool
	JoinAsAttendee()
	JoinWaitlist()
	ListRoles() []string
	Publish(markdown string)
	RegisterEvent(evt *Event, opts map[string]interface{}) string
	RemoveOrganizer(addr std.Address)
	RemoveProposer(addr, sender std.Address)
	RemoveReviewer(addr, sender std.Address)
	RemoveSelfAsAttendee()
	RemoveSelfFromWaitlist()
	RemoveSpeaker(addr std.Address)
	Render(path string) string
	RenderAcl(path string) string
	RenderList(role string) string
	ResetRoles()
	RoleExists(role string) bool
	SetContent(key, markdown string)
	SetPatchLevel(level int)
	SetRoleHandler(role string, fn func(string) bool)
	Unpublish(key string)
	UnsetRoleHandler(role string)
}

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
	renderOpts  map[string]interface{}
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

func (evt *Event) GetSessions() []*session.Session {
	if evt.storage == nil || evt.storage.Sessions == nil {
		return nil
	}
	var sessions []*session.Session
	evt.storage.Sessions.IterateByOffset(0, evt.storage.Sessions.Size(), func(_ string, val any) bool {
		s := val.(*session.Session)
		sessions = append(sessions, s)
		return false
	})
	return sessions
}

func (evt *Event) Agenda(heading *component.Content) *agenda.Agenda {
	a := &agenda.Agenda{
		Name:        evt.Name,
		Location:    evt.Location,
		StartDate:   evt.StartDate,
		EndDate:     evt.EndDate,
		Description: evt.Description,
		Sessions:    evt.Sessions,
	}
	a.SetBanner(heading)
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
func (evt *Event) RenderOpts() map[string]interface{} {
	return evt.renderOpts
}

func (evt *Event) SetRenderOpts(opts map[string]interface{}) {
	evt.renderOpts = opts
}

func (evt *Event) ToAnchor() string {
	return component.StringToAnchor(evt.Name)
}

func (evt *Event) ToMarkdown(heading ...component.Content) string {
    if len(heading) == 0 {
        heading = append(heading, component.Content{ Published: false})
    }
	return evt.Agenda(&heading[0]).ToMarkdown()
}

func (evt *Event) ToSvgDataUrl() string {
    heading := &component.Content{ Published: false }
	return evt.Agenda(heading).ToSvgDataUrl()
}

func (evt *Event) ToSVG() string {
    heading := &component.Content{ Published: false }
	return evt.Agenda(heading).ToSVG()
}

const DateFormatJsonLD = "2006-01-02T15:04:05-07:00"

func (evt *Event) ToJson() string {
	return `{
    "@context": "https://schema.org",
    "@type": "Event",
    "name": "` + ufmt.Sprintf("%s", evt.Name) + `",
    "startDate": "` + ufmt.Sprintf("%s", evt.StartDate.Format(DateFormatJsonLD)) + `",
    "endDate": "` + ufmt.Sprintf("%s", evt.EndDate.Format(DateFormatJsonLD)) + `",
    "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode", // FIXME: make this a feature of the event
    "eventStatus": "https://schema.org/EventScheduled",
    "location": { // FIXME: make this conditional? or make sure virtual events are representable
        "@type": "Place",
        "name": "` + ufmt.Sprintf("%s", evt.Location.Name) + `"
    },
    "image": [],
    "description": "` + ufmt.Sprintf("%s", evt.Description) + `"
	}`
}
