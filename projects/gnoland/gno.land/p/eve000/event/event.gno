package event

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/eve000/event/component"
)

// FIXME either change interface or satisfy it
//var _ Api = (*Event)(nil)

type Api interface {
	AddOrganizer(addr std.Address)
	AddProposer(addr, sender std.Address)
	AddReviewer(addr, sender std.Address)
	AddSpeaker(addr std.Address)
	AdminRemoveRole(role string, addr std.Address)
	AdminSetRole(role string, addr std.Address)
	AssertAtLeastRole(role string, sender std.Address)
	HasRole(role string, addr std.Address) bool
	JoinAsAttendee()
	JoinWaitlist()
	ListRoles() []string
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
	UnsetRoleHandler(role string)
}

type Storage struct {
	Sessions  *avl.Tree
	Speakers  *avl.Tree
	Locations *avl.Tree
}

// REVIEW: Event / Flyer are duals of each other.
// we return Flyer objects to non-admin users - (lacking any edit methods)
// the event object is protected for edits only by patching from specific 'sub-realms'
type Event struct {
	Name           string
	Location       *component.Location
	StartDate      time.Time
	EndDate        time.Time
	Description    string
	Sessions       []*component.Session
	Status         component.EventStatus
	AttendanceMode component.EventAttendanceMode
	Images         []string
	renderOpts     map[string]interface{}
	storage        *Storage
}

func (evt *Event) SetEventName(name string) {
	evt.Name = name
}

func (evt *Event) SetEventLocation(loc *component.Location) {
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

func (evt *Event) SetSessions(sessions []*component.Session) {
	evt.Sessions = sessions
}

func (evt *Event) AddSpeaker(s *component.Speaker) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Speakers == nil {
		evt.storage.Speakers = &avl.Tree{}
	}
	id := component.Pad3(strconv.Itoa(evt.storage.Speakers.Size()))
	evt.storage.Speakers.Set(component.Pad3(id), s)
}

func (evt *Event) AddLocation(loc *component.Location) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Locations == nil {
		evt.storage.Locations = &avl.Tree{}
	}
	id := component.Pad3(strconv.Itoa(evt.storage.Locations.Size()))
	evt.storage.Locations.Set(component.Pad3(id), loc)
}

func (evt *Event) AddSession(sess *component.Session) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Sessions == nil {
		evt.storage.Sessions = &avl.Tree{}
	}
	// TODO: maybe Pad3 can accept interface so extras stringconv isn't needed here
	id := component.Pad3(strconv.Itoa(evt.storage.Sessions.Size()))
	evt.storage.Sessions.Set(component.Pad3(id), sess)
}

func (evt *Event) GetSpeaker(id string) *component.Speaker {
	s, ok := evt.storage.Speakers.Get(component.Pad3(id))
	if !ok {
		panic("speaker not found: id=" + id)
	}
	return s.(*component.Speaker)
}

func (evt *Event) GetLocation(id string) *component.Location {
	l, ok := evt.storage.Locations.Get(component.Pad3(id))
	if !ok {
		panic("location not found: id=" + id)
	}
	return l.(*component.Location)
}

func (evt *Event) GetSession(id string) *component.Session {
	s, ok := evt.storage.Sessions.Get(component.Pad3(id))
	if !ok {
		panic("session not found: id=" + id)
	}
	return s.(*component.Session)
}

func (evt *Event) Flyer() *component.Flyer {
	flyer := &component.Flyer{
		Name:        evt.Name,
		Location:    nil,
		StartDate:   evt.StartDate,
		EndDate:     evt.EndDate,
		Status:      evt.Status,
		Description: evt.Description,
		Sessions:    nil,
		Images:      append([]string(nil), evt.Images...),
	}
	if evt.Location != nil {
		loc := *evt.Location
		flyer.Location = &loc
	}
	if evt.Sessions != nil {
		flyer.Sessions = make([]*component.Session, len(evt.Sessions))
		for i, s := range evt.Sessions {
			if s != nil {
				sessionCopy := *s
				flyer.Sessions[i] = &sessionCopy
			}
		}
	}
	flyer.SetRenderOpts(evt.renderOpts)
	return flyer
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

// Render provides a syntactic sugar for rendering a Flyer using a template function.
func (evt *Event) Render(path string, tpl func(path string, flyer *component.Flyer) string) string {
	return tpl(path, evt.Flyer())
}
