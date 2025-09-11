package officehours

import (
	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

type Registry struct {
	Tree *avl.Tree
}

func (r Registry) Get(episode string) (Record, bool) {
	if r.Tree == nil {
		return Record{}, false
	}
	if val, found := r.Tree.Get(episode); found {
		return val.(Record), true
	}
	return Record{}, false
}

func (r Registry) Exists(episode string) bool {
	_, exists := r.Get(episode)
	return exists
}

func (r Registry) AssertExists(episode string) {
	if !r.Exists(episode) {
		panic("Episode not found: " + episode)
	}
}

func (r Registry) Register(episodes map[string]Record) {
    assertAccess()
	if r.Tree == nil {
		r.Tree = avl.NewTree()
	}
	for name, rec := range episodes {
		if r.Exists(name) {
			panic("Episode already registered: " + name)
		}
		r.Tree.Set(name, rec)
	}
}

// Extend allows adding additional EvtWriters to an existing episode record.
// this is useful for adding custom behavior without modifying the original registration.
func (r Registry) Extend(name string, writers ...EvtWriter) {
	rec, exists := r.Get(name)
	if !exists {
		panic("Episode not found: " + name)
	}
	for _, w := range writers {
		w(&eve.Flyer{}, map[string]any{})
	}
	r.Tree.Set(name, Record{
		Episode:    rec.Episode,
		Content:    rec.Content,
		EvtWriters: append(rec.EvtWriters, writers...),
		Meta:       rec.Meta,
	})
}
