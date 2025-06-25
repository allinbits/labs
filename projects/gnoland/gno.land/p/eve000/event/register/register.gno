package register

import (
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/component"
)

type Registry struct {
	Events      *avl.Tree
	LiveEventId string
	renderOpts  *component.RenderOpts
}

func (r *Registry) GetEvent(id string) *event.Event {
	e, ok := r.Events.Get(event.AvlKey("event", id))
	if !ok {
		panic("event not found" + id)
	}
	return e.(*event.Event)
}

func (r *Registry) SetRenderOpts(opts *component.RenderOpts) {
	r.renderOpts = opts
}

func (r *Registry) String() string {
	return ufmt.Sprintf("Registry{LiveEventId: %v, Events Size: %v}", r.LiveEventId, r.Events.Size())
}

func (r *Registry) RegisterEvent(e *event.Event, opts *component.RenderOpts) string {
	if r.Events == nil {
		r.Events = avl.NewTree()
	}
	e.SetRenderOpts(opts)

	for _, s := range e.Sessions {
		s.SetRenderOpts(opts)
		e.AddSession(s)
		s.Speaker.SetRenderOpts(opts)
		e.AddSpeaker(s.Speaker)
		s.Location.SetRenderOpts(opts)
		e.AddLocation(s.Location)
	}

	id := event.Pad3(strconv.Itoa(r.Events.Size()))
	println("Registering gnolandlaunch with id=" + id)
	r.Events.Set(id, e)
	return id
}
