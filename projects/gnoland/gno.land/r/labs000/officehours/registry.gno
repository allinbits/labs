package officehours

import (
    "std"
)

type Registry struct {
    Records map[string]Record
}

func (r Registry) AssertExists(episode string) {
    if _, exists := r.Records[episode]; !exists {
        panic("Episode not registered: " + episode)
    }
}

func (r Registry) UpVote(episode, cid string) {
    r.AssertExists(episode)
    std.Emit("UpVote", "cid", cid[:10], "episode", episode)
}

func (r Registry) DownVote(episode, cid string) {
    r.AssertExists(episode)
    std.Emit("DownVote", "cid", cid[:10], "episode", episode)
}

func (r Registry) Register(episodes map[string]Record) {
    if r.Records == nil {
        r.Records = map[string]Record{}
    }
	for name, rec := range episodes {
		if _, exists := r.Records[name]; exists {
			panic("Episode already registered: " + name)
		}
		r.Records[name] = rec
	}
}

// Extend allows adding additional EvtWriters to an existing episode record.
// this is useful for adding custom behavior without modifying the original registration.
func (r Registry) Extend(name string, writers ...EvtWriter) {
	if rec, ok := r.Records[name]; ok {
		r.Records[name] = Record{
			Episode:    rec.Episode,
			Content:    rec.Content,
			EvtWriters: append(rec.EvtWriters, writers...),
			Meta:       rec.Meta,
		}
	} else {
		panic("Episode not found: " + name)
	}
}