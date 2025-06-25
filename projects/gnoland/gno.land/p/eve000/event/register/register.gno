package register

import (
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
