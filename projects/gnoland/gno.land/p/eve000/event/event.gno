package event

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

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
	// REVIEW: should setLive Event be part of the API? - we may not use due to versioning issues
	PublishEvent(evt *Event, opts map[string]interface{}) string
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
	Location       *eve.Location
	StartDate      time.Time
	EndDate        time.Time
	Description    string
	Sessions       []*eve.Session
	Status         eve.EventStatus
	AttendanceMode eve.EventAttendanceMode
	Images         []string
	renderOpts     map[string]interface{}
	storage        *Storage
}

func (evt *Event) SetEventName(name string) {
	evt.Name = name
}

func (evt *Event) SetEventLocation(loc *eve.Location) {
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

func (evt *Event) SetSessions(sessions []*eve.Session) {
	evt.Sessions = sessions
}

func (evt *Event) AddSpeaker(s *eve.Speaker) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Speakers == nil {
		evt.storage.Speakers = &avl.Tree{}
	}
	id := eve.Pad3(evt.storage.Speakers.Size())
	evt.storage.Speakers.Set(eve.Pad3(id), s)
}

func (evt *Event) AddLocation(loc *eve.Location) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Locations == nil {
		evt.storage.Locations = &avl.Tree{}
	}
	id := eve.Pad3(evt.storage.Locations.Size())
	evt.storage.Locations.Set(eve.Pad3(id), loc)
}

func (evt *Event) AddSession(sess *eve.Session) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Sessions == nil {
		evt.storage.Sessions = &avl.Tree{}
	}
	id := eve.Pad3(strconv.Itoa(evt.storage.Sessions.Size()))
	evt.storage.Sessions.Set(eve.Pad3(id), sess)
}

func (evt *Event) GetSpeaker(id string) *eve.Speaker {
	s, ok := evt.storage.Speakers.Get(eve.Pad3(id))
	if !ok {
		panic("speaker not found: id=" + id)
	}
	return s.(*eve.Speaker)
}

func (evt *Event) GetLocation(id string) *eve.Location {
	l, ok := evt.storage.Locations.Get(eve.Pad3(id))
	if !ok {
		panic("location not found: id=" + id)
	}
	return l.(*eve.Location)
}

func (evt *Event) GetSession(id string) *eve.Session {
	s, ok := evt.storage.Sessions.Get(eve.Pad3(id))
	if !ok {
		panic("session not found: id=" + id)
	}
	return s.(*eve.Session)
}

func (evt *Event) Flyer() *eve.Flyer {
	flyer := &eve.Flyer{
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
		flyer.Sessions = make([]*eve.Session, len(evt.Sessions))
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

func (evt *Event) RenderOpts() map[string]interface{} {
	return evt.renderOpts
}

func (evt *Event) initStorage() {
	for _, s := range evt.Sessions {
		evt.AddSession(s)
		evt.AddSpeaker(s.Speaker)
		evt.AddLocation(s.Location)
	}
}

func (evt *Event) SetRenderOpts(opts map[string]interface{}) {
	chainId := std.ChainID()
	if _, ok := opts[chainId]; !ok {
		panic("render options must be set for the current chain: " + chainId)
	}
	renderOpts, ok := opts[chainId].(map[string]interface{})
	if !ok {
		panic("render options must be a map[string]interface{} for the current chain: " + chainId)
	}
	evt.renderOpts = renderOpts

	if evt.storage == nil {
		evt.initStorage()
	}
	for _, s := range evt.Sessions {
		s.SetRenderOpts(evt.renderOpts)
		if s.Speaker != nil {
			s.Speaker.SetRenderOpts(evt.renderOpts)
		} else {
			s.Speaker = &eve.Speaker{}
		}
		if s.Location != nil {
			s.Location.SetRenderOpts(evt.renderOpts)
		} else {
			s.Location = &eve.Location{}
		}
	}
}

func (evt *Event) ToAnchor() string {
	return eve.StringToAnchor(evt.Name)
}

// Render provides a syntactic sugar for rendering a Flyer using a template function.
func (evt *Event) Render(path string, tpl func(path string, flyer *eve.Flyer) string) string {
	return tpl(path, evt.Flyer())
}

func (evt *Event) RenderPage(path string, body ...eve.Content) string {
	q := eve.QueryValues(path)
	switch {
	case eve.HasQueryParam(q, "session"):
		return eve.RenderComponent(path, evt.GetSession(q.Get("session")))
	case eve.HasQueryParam(q, "location"):
		return eve.RenderComponent(path, evt.GetLocation(q.Get("location")))
	case eve.HasQueryParam(q, "speaker"):
		return eve.RenderComponent(path, evt.GetSpeaker(q.Get("speaker")))
	default:
	}
	return eve.RenderPage(path, evt.Flyer(), body...)
}

func (evt *Event) RenderContent(path string, blocks []*eve.Content) string {
    var body []eve.Content
    for _, b := range blocks {
        if b != nil {
            body = append(body, *b)
        }
    }

    return eve.RenderPage(path, evt.Flyer(), body...)
}
