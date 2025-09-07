package officehours

import (
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

type Registry map[string]any

func (r Registry) Register(episodes map[string]Record) {
	for name, rec := range episodes {
		if _, exists := r[name]; exists {
			panic("Episode already registered: " + name)
		}
		r[name] = rec
	}
}

// Extend allows adding additional EvtWriters to an existing episode record.
// this is useful for adding custom behavior without modifying the original registration.
func (r Registry) Extend(name string, writers ...EvtWriter) {
	if rec, ok := r[name]; ok {
		r[name] = Record{
			Episode:    rec.(Record).Episode,
			Content:    rec.(Record).Content,
			EvtWriters: append(rec.(Record).EvtWriters, writers...),
		}
	} else {
		panic("Episode not found: " + name)
	}
}

var (
	registry = Registry{}
)

func Register(episodes map[string]Record) {
	registry.Register(episodes)
}

var e0 = "http://127.0.0.1:8888/r/labs000/officehours/season001/episode000?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z"
var e1 = "http://127.0.0.1:8888/r/labs000/officehours/season001/episode001?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z"

// TODO: make this use the registry + add an additional storage for links to recordings

func Render(path string) string {
	return `
# Office Hours
- episode | [index](?)

| Recording        | Episode |
|----------------|-|
| [s001e000](https://example.com/path-to-video.mkv) | [HowTo: add episodes](` + e0 + `)
| [s001e001](                               ) | [Wtf is the Logoverse?](` + e1 + `)
| [s001e002](                               ) | [$Tickers](/r/labs000/officehours/season001/episode002)
| [s001e003](                               ) | [Petri-Nets](/r/labs000/officehours/season001/episode003)
| [s001e004](                               ) | [GRC-000](/r/labs000/officehours/season001/episode004)
| [s001e005](                               ) | [GRC-20](/r/labs000/officehours/season001/episode005)
| [s001e006](                               ) | [Modeling101](/r/labs000/officehours/season001/episode006)
| [s001e007](                               ) | [Modeling201](/r/labs000/officehours/season001/episode007)
| [s001e008](                               ) | [Simulation with Petri.jl](/r/labs000/officehours/season001/episode008)
| [s001e009](                               ) | [Fungible Objects](/r/labs000/officehours/season001/episode009)
| [s001e010](                               ) | [Wtf does Fungible Mean Anyway?](/r/labs000/officehours/season001/episode010)
| [s001e011](                               ) | [Yoneda: You are known by what you do. ](/r/labs000/officehours/season001/episode011)
| [s001e012](                               ) | [Forgetting in Category Theory](/r/labs000/officehours/season001/episode012)

`
}

func DefaultOpts() map[string]any {
	return map[string]any{
		"dev":      map[string]any{},
		"labsnet1": map[string]any{},
	}
}

type EvtWriter = func(evt *event.Event, opts map[string]any)

func ApplyScheduleOptionsFromPath(evt *event.Event, opts map[string]any) {
	evt.SetRenderOpts(opts)

	if d, ok := opts["startDate"]; ok {
		evt.StartDate = d.(time.Time)
		for _, s := range evt.Sessions {
			s.StartTime = d.(time.Time)
		}
	}

	if d, ok := opts["endDate"]; ok {
		evt.EndDate = d.(time.Time)
		for _, s := range evt.Sessions {
			s.EndTime = d.(time.Time)
		}
	}

	if status, ok := opts["status"]; ok {
		evt.Status = eve.Status(status.(string))
	}
}

var _ EvtWriter = ApplyScheduleOptionsFromPath

type Record struct {
	Episode    func(map[string]any) *event.Event
	Content    []*eve.Content
	EvtWriters []EvtWriter // Yoneda move: objects are known by how they’re probed (the writers).
	Meta       []string
}

func (rec Record) RenderCalendar(path string) string {
    opts := GetScheduleOpts(path)
	evt := rec.Episode(WithSpeaker(opts))
	evt.SetRenderOpts(opts)
	return evt.Render(path, eve.IcsCalendarFile)
}

func RenderEpisode(path string, rec Record) string {
	q := eve.ParseQuery(path)
	var evt *event.Event
	page := q.Get("p")
	opts := GetScheduleOpts(path)

	applySetters := func(evt *event.Event) *event.Event {
		for _, opSetter := range rec.EvtWriters {
			opSetter(evt, opts)
		}
		return evt
	}

	switch page {
	case "json":
		evt := applySetters(rec.Episode(WithSpeaker(opts)))
		return "```json\n" + (evt.Flyer()).ToJson() + "\n```"
	case "calendar":
		evt := applySetters(rec.Episode(WithSpeaker(opts)))
		ics := evt.Render(path, eve.IcsCalendarFile)
		return "```" + ics + "```"
	case "speakers":
		evt = applySetters(rec.Episode(WithSpeaker(opts)))
	default:
		evt = applySetters(rec.Episode(WithoutTitle(opts)))
	}
	return evt.RenderContent(path, rec.Content)
}

// GetScheduleOpts extracts scheduling options from the URL path query parameters.
// Example: episode001?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z
func GetScheduleOpts(path string) map[string]any {
	q := eve.ParseQuery(path)
	// FIXME: using two levels here .. nested under dev and then at root
	opts := DefaultOpts() // REVIEW consider using other composables here
	if q.Get("status") != "" {
		opts["status"] = q.Get("status")
	}
	if q.Get("startDate") != "" {
		if t, err := time.Parse(time.RFC3339, q.Get("startDate")); err == nil {
			opts["startDate"] = t
		}
	}
	if q.Get("endDate") != "" {
		if t, err := time.Parse(time.RFC3339, q.Get("endDate")); err == nil {
			opts["endDate"] = t
		}
	}
	return opts
}

func OptsWithKeyValue(key string, value any, inputOpts ...map[string]any) map[string]any {
	opts := map[string]any{}
	if len(inputOpts) > 0 {
		opts = inputOpts[0]
	}
	for k, v := range DefaultOpts() {
		opts[k] = v
		opts[k].(map[string]any)[key] = value
	}
	return opts
}

func WithoutTitle(opts ...map[string]any) map[string]any {
	return OptsWithKeyValue("SessionsTitle", "", opts...)
}

func WithSpeaker(opts ...map[string]any) map[string]any {
	return OptsWithKeyValue("Speaker", struct{}{}, opts...)
}

func ContentBlock(content string) *eve.Content {
	return &eve.Content{Published: true, Markdown: content}
}

func Nav(md ...string) []*eve.Content {
    var blocks []*eve.Content
    for _, m := range md {
        blocks = append(blocks, ContentBlock(m))
    }
    return blocks
}

func Writer(writers ...EvtWriter) []EvtWriter {
    return writers
}

func Keywords(tags ...string) []string {
    return tags
}