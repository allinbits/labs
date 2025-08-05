package event

import (
	"net/url"
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
)

type Registry struct {
	Events      *avl.Tree
	LiveEventId string
	RenderOpts  map[string]interface{}
	patchLevel  int    // current patch level, used for debugging and content management
	patchRealm  string // realm that is allowed to update the patch level, used for debugging and content management
}

func (r *Registry) Render(path string, body ...component.Content) string {
	fullURL := std.CurrentRealm().PkgPath() + path // REVIEW: is this really needed?
	u, err := url.Parse(fullURL)
	if err != nil {
		panic("Error Parsing URL")
	}
	q := u.Query()
	event_id := q.Get("event")
	if event_id == "" {
		event_id = r.LiveEventId
	}
	evt := r.GetEvent(event_id)
	switch {
	case component.HasQueryParam(q, "session"):
		return component.RenderComponent(path, evt.GetSession(q.Get("session")))
	case component.HasQueryParam(q, "location"):
		return component.RenderComponent(path, evt.GetLocation(q.Get("location")))
	case component.HasQueryParam(q, "speaker"):
		return component.RenderComponent(path, evt.GetSpeaker(q.Get("speaker")))
	default:
		return component.RenderPage(path, evt.Flyer(), body...)
	}
}

func NewRegistry(renderOpts map[string]interface{}) *Registry {
	return &Registry{
		Events:      avl.NewTree(),
		LiveEventId: "",
		RenderOpts:  renderOpts,
		patchLevel:  0,
		patchRealm:  "",
	}
}

func (r *Registry) GetPatchLevel() string {
	realmLink := strings.TrimPrefix(r.patchRealm, "gno.land")
	return ufmt.Sprintf("[rev %d](%s)", r.patchLevel, realmLink)
}

func (r *Registry) SetPatchLevel(level int) {
	if r.patchLevel+1 != level {
		panic("patch level must be incremented by 1, current: " + strconv.Itoa(r.patchLevel) + ", new: " + strconv.Itoa(level))
	}
	r.patchRealm = std.CurrentRealm().PkgPath()
	r.patchLevel = level
}

func (r *Registry) GetEvent(id string) *Event {
	e, ok := r.Events.Get(component.Pad3(id))
	if !ok {
		panic("event not found" + id)
	}
	return e.(*Event)
}

func (r *Registry) SetRenderOpts(opts map[string]interface{}) {
	r.RenderOpts = opts
}

func (r *Registry) String() string {
	return ufmt.Sprintf("Registry{LiveEventId: %v, Events Size: %v}", r.LiveEventId, r.Events.Size())
}

func (r *Registry) RegisterEvent(e *Event, opts map[string]interface{}) string {
	if r.Events == nil {
		r.Events = avl.NewTree()
	}
	e.SetRenderOpts(opts)

	id := component.Pad3(strconv.Itoa(r.Events.Size())) // 001, 002, etc.
	r.Events.Set(id, e)
	return id
}
