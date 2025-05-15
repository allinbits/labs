package register

import (
	"gno.land/p/demo/avl"

	"gno.land/p/eve/event"
	"gno.land/p/eve/event/component"
	"gno.land/p/eve/event/location"
	"gno.land/p/eve/event/session"
	"gno.land/p/eve/event/speaker"
)

type Registry struct {
	EventSeq    int
	SpeakerSeq  int
	LocationSeq int
	SessionSeq  int
	Storage     *Storage
	renderOpts  *component.RenderOpts
}

type Storage struct {
	Events    *avl.Tree
	Sessions  *avl.Tree
	Speakers  *avl.Tree
	Locations *avl.Tree
}

func NewRegistry(opts *component.RenderOpts, seq ...int) *Registry {
	startSeq := 0
	if len(seq) == 1 {
		startSeq = seq[0]
	}
	return &Registry{
		EventSeq:    startSeq,
		SpeakerSeq:  startSeq,
		SessionSeq:  startSeq,
		LocationSeq: startSeq,
		Storage: &Storage{
			Events:    avl.NewTree(),
			Sessions:  avl.NewTree(),
			Speakers:  avl.NewTree(),
			Locations: avl.NewTree(),
		},
		renderOpts: opts, // REVIEW: consider breaking out-per-event vs per-registry as it is
	}
}

func (registry *Registry) RegisterEvent(e *event.Event) int {
	e.SetRenderOpts(registry.renderOpts)
	registry.Storage.Events.Set(event.AvlKey("event", registry.EventSeq), e)
	registry.EventSeq++

	for _, s := range e.Sessions {
		s.SetRenderOpts(e.RenderOpts())
		s.Speaker.SetRenderOpts(e.RenderOpts())

		registry.AddSession(s)
		registry.AddSpeaker(s.Speaker)
		registry.AddLocation(s.Location)
	}

	return registry.EventSeq - 1
}

func (registry *Registry) GetSpeaker(id int) *speaker.Speaker {
	s, ok := registry.Storage.Speakers.Get(event.AvlKey("speaker", id))
	if !ok {
		panic("speaker not found")
	}
	return s.(*speaker.Speaker)
}

func (registry *Registry) GetLocation(id int) *location.Location {
	l, ok := registry.Storage.Locations.Get(event.AvlKey("location", id))
	if !ok {
		panic("location not found")
	}
	return l.(*location.Location)
}

func (registry *Registry) GetEvent(id int) *event.Event {
	e, ok := registry.Storage.Events.Get(event.AvlKey("event", id))
	if !ok {
		panic("event not found")
	}
	return e.(*event.Event)
}

func (registry *Registry) GetEventSession(eventId, id int) *session.Session {
	e := registry.GetEvent(eventId)
	if id >= len(e.Sessions) {
		panic("session not found")
	}
	return e.Sessions[id]
}

func (registry *Registry) GetSession(id int) *session.Session {
	s, ok := registry.Storage.Sessions.Get(event.AvlKey("session", id))
	if !ok {
		panic("session not found")
	}
	return s.(*session.Session)
}

func (registry *Registry) AddSession(s *session.Session) int {
	s.SetRenderOpts(registry.renderOpts)
	registry.Storage.Sessions.Set(event.AvlKey("session", registry.SessionSeq), s)
	registry.SessionSeq++
	return registry.SessionSeq - 1
}

func (registry *Registry) AddSpeaker(s *speaker.Speaker) int {
	s.SetRenderOpts(registry.renderOpts)
	registry.Storage.Speakers.Set(event.AvlKey("speaker", registry.SpeakerSeq), s)
	registry.SpeakerSeq++
	return registry.SpeakerSeq - 1
}

func (registry *Registry) AddLocation(l *location.Location) int {
	registry.Storage.Locations.Set(event.AvlKey("location", registry.LocationSeq), l)
	registry.LocationSeq++
	return registry.LocationSeq - 1
}

func (registry *Registry) IncrementEventSeq() int {
	registry.EventSeq++
	return registry.EventSeq
}
