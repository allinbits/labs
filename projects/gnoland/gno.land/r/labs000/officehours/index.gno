package officehours

import (
	"time"
	"strings"
	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)
var e0 = "http://127.0.0.1:8888/r/labs000/officehours/season001/episode000?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z"
var e1 = "http://127.0.0.1:8888/r/labs000/officehours/season001/episode001?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z"

// TODO: make this use the registry + add an additional storage for links to recordings

func Render(path string) string {
	return `
# Office Hours
[` + AllInBits.Image() +`](/r/labs000/officehours)
- episode | [index](?) | [help](?p=help) | [propose](?p=propose)

| Recording        | Episode |
|----------------|-|
| [s001e000](https://example.com/path-to-video.mkv) | [HowTo: add episodes](` + e0 + `)
| [s001e001](                               ) | [Wtf is the Logoverse?](` + e1 + `)

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
	evt.SetRenderOpts(opts) // TODO: should opts + renderOpts be separate?

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

// GetScheduleOpts extracts scheduling options from the URL path query parameters.
// Example: episode001?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z
func GetScheduleOpts(path string) map[string]any {
	q := eve.ParseQuery(path)
	// FIXME: using two levels here .. nested under dev and then at root
	opts := DefaultOpts() // REVIEW consider using other composables here
	if q.Get("cid") != "" {
	     opts["ExpectedCid"] = q.Get("cid")
    }
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

func OptsToPath(opts map[string]any) string {
    var q []string
    if status, ok := opts["status"]; ok {
        q = append(q, "status="+status.(string))
    }
    if startDate, ok := opts["startDate"]; ok {
        q = append(q, "startDate="+startDate.(time.Time).Format(time.RFC3339))
    }
    if endDate, ok := opts["endDate"]; ok {
        q = append(q, "endDate="+endDate.(time.Time).Format(time.RFC3339))
    }
    if cid, ok := opts["ExpectedCid"]; ok {
        q = append(q, "cid="+cid.(string))
    }
    if len(q) > 0 {
        return "?" + strings.Join(q, "&")
    }
    return ""
}

func Normalize(path string) string {
    return OptsToPath(GetScheduleOpts(path))
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

func InDraft(evt *event.Event, opts map[string]any) {
    evt.Name = evt.Name + " (draft)"
}

func PublishDraft(evt *event.Event, opts map[string]any) {
    if strings.HasSuffix(evt.Name, " (draft)") {
        evt.Name = evt.Name[:len(evt.Name)-8]
    }
}

