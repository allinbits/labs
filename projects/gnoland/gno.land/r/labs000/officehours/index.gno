package officehours
import (
    "time"
	eve "gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event"
)

type Registry map[string]any

func(r Registry) register(events map[string]*eve.Flyer) {
    for name, evt := range events {
        r[name] = evt
    }
}

var (
	registry = map[string]any{}
)

func register(events map[string]*eve.Flyer) {
    for name, evt := range events {
        registry[name] = evt
    }
}

func Render(path string) string {
	return `
# Office Hours
- episode | [index](?)

| Recording        | Episode |
|----------------|-|
| [s001e001](https://example.com/path-to-video.mkv) | [Wtf is the Logoverse?](/r/labs000/officehours/season001/episode001)
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
		"dev": map[string]any{},
		"labsnet1": map[string]any{},
	}
}

func RenderEpisode(path string, episode func(map[string]any) *event.Event, content []eve.Content) string {
	q := eve.ParseQuery(path)
	var evt *event.Event
	page := q.Get("p")
	opts := GetOpts(path)
	switch page {
	case "calendar":
        evt := episode(WithSpeaker(GetOpts(path)))
        ics := evt.Render(path, eve.IcsCalendarFile)
        return "```" + ics + "```"
	case "speakers":
		evt = episode(WithSpeaker(opts))
	default:
		evt = episode(WithoutTitle(opts))
	}
	return evt.RenderPage(path, content...)
}

func GetOpts(path string) map[string]any {
    q := eve.ParseQuery(path)
    opts := map[string]any{}
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
