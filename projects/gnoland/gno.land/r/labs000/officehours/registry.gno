package officehours

type Registry struct {
    records map[string]Record
}

func (r Registry) AssertExists(episode string) {
    if _, exists := r.records[episode]; !exists {
        panic("Episode not registered: " + episode)
    }
}

func (r Registry) Register(episodes map[string]Record) {
    if r.records == nil {
        r.records = map[string]Record{}
    }
	for name, rec := range episodes {
		if _, exists := r.records[name]; exists {
			panic("Episode already registered: " + name)
		}
		r.records[name] = rec
	}
}

// Extend allows adding additional EvtWriters to an existing episode record.
// this is useful for adding custom behavior without modifying the original registration.
func (r Registry) Extend(name string, writers ...EvtWriter) {
	if rec, ok := r.records[name]; ok {
		r.records[name] = Record{
			Episode:    rec.Episode,
			Content:    rec.Content,
			EvtWriters: append(rec.EvtWriters, writers...),
			Meta:       rec.Meta,
		}
	} else {
		panic("Episode not found: " + name)
	}
}