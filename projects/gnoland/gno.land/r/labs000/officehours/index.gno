package officehours

import (
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

type Registry map[string]any

func (r Registry) Register(episodes map[string]Record) {
	for name, rec := range episodes {
		r[name] = rec
	}
}

func (r Registry) Extend(name string, setters ...EvtWriter) {
	if rec, ok := r[name]; ok {
		r[name] = Record{
			Episode:    rec.(Record).Episode,
			Content:    rec.(Record).Content,
			EvtWriters: append(rec.(Record).EvtWriters, setters...),
		}
	}
}

var (
	registry = Registry{}
)

func Register(episodes map[string]Record) {
	registry.Register(episodes)
}

var e1 = "http://127.0.0.1:8888/r/labs000/officehours/season001/episode001?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z"

// TODO: make this use the registry + add an additional storage for links to recordings

func Render(path string) string {
	return `
# Office Hours
- episode | [index](?)

| Recording        | Episode |
|----------------|-|
| [s001e001](https://example.com/path-to-video.mkv) | [Wtf is the Logoverse?](` + e1 + `)
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

func ApplyOptionsFromPath(evt *event.Event, opts map[string]any) {
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

var _ EvtWriter = ApplyOptionsFromPath

type Record struct {
	Episode    func(map[string]any) *event.Event
	Content    []eve.Content
	EvtWriters []EvtWriter
}

func (rec Record) RenderCalendar(path string) string {
	evt := rec.Episode(WithSpeaker(GetOpts(path)))
	evt.SetRenderOpts(GetOpts(path))
	return evt.Render(path, eve.IcsCalendarFile)
}

func RenderEpisode(path string, rec Record) string {
	q := eve.ParseQuery(path)
	var evt *event.Event
	page := q.Get("p")
	opts := GetOpts(path)

	applySetters := func(evt *event.Event) *event.Event {
		for _, opSetter := range rec.EvtWriters {
			opSetter(evt, opts)
		}
		return evt
	}

	switch page {
	case "json":
		evt := applySetters(rec.Episode(WithSpeaker(GetOpts(path))))
		return "```json\n" + (evt.Flyer()).ToJson() + "\n```"
	case "calendar":
		evt := applySetters(rec.Episode(WithSpeaker(GetOpts(path))))
		ics := evt.Render(path, eve.IcsCalendarFile)
		return "```" + ics + "```"
	case "speakers":
		evt = applySetters(rec.Episode(WithSpeaker(opts)))
	default:
		evt = applySetters(rec.Episode(WithoutTitle(opts)))
	}
	return evt.RenderPage(path, rec.Content...)
}

// GetOpts extracts known options from the URL query parameters.
// Example: episode001?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z
func GetOpts(path string) map[string]any {
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

func ContentBlock(content string) eve.Content {
	return eve.Content{Published: true, Markdown: content}
}
