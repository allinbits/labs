package officehours

import (
	"strings"
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
	logo "gno.land/r/labs000/logoverse"
)

// Render can display registered episodes and their recordings. Proposals can be made for new sessions.
func Render(path string) string {
	q := eve.ParseQuery(path)
	if p := q.Get("p"); p != "" {
		switch p {
		case "propose":
			return Episode.Record()[S000E000].Render(path)
		default:
		}
	}
	if p := q.Get("episode"); p != "" {
		if rec, ok := registry.Get(p); ok {
			return rec.Render(path)
		}
	}

	if cid := q.Get("cid"); cid != "" {
		return "Thank you for your proposal! Your proposal ID is: " + cid + "\n\n" + RenderStatic(path)
	}
	return RenderStatic(path)
}

// TODO: refactor to replace this
func RenderStatic(path string) string {
	var e1 = "?episode=s001e001&status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z"
	return `
# Office Hours
[` + logo.AllInBits.Image() + `](/r/labs000/officehours)
- episode | [index](?) | [help](?p=help) | [propose](` + todayLink() + `)

| Recording        | Episode |
|----------------|-|
|    upcoming     | [Propose a session → ](` + todayLink() + `)
| [s001e001](https://example.com/path-to-video.mkv) | [Wtf is the Logoverse?](` + e1 + `)

`
}

// DefaultOpts provides a base structure for displaying events.
func DefaultOpts() map[string]any {
	return map[string]any{
		"dev":      map[string]any{}, // REVIEW: chainIds are used to provide a chain-level opts namespace
		"labsnet1": map[string]any{},
	}
}

type EvtWriter = func(evt *event.Event, opts map[string]any)

// ApplyScheduleOptionsFromPath applies scheduling options from the provided opts map to the event.
func ApplyScheduleOptionsFromPath(evt *event.Event, opts map[string]any) {
	evt.SetRenderOpts(opts) // TODO: should opts + renderOpts be separate?

	if d, ok := opts["description"]; ok {
		for _, s := range evt.Sessions {
			s.Description = d.(string)
		}
	}

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
//
//	[example](episode001?status=EventScheduled&startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z)
func GetScheduleOpts(path string) map[string]any {
	q := eve.ParseQuery(path)
	// FIXME: using two levels here .. nested under dev and then at root
	opts := DefaultOpts() // REVIEW consider using other composables here
	if q.Get("status") != "" {
		opts["status"] = q.Get("status")
	}
	// TODO: do title

	// FIXME make sure description propagates to permalink
	if q.Get("description") != "" {
		opts["description"] = q.Get("description")
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
	// TODO: add options for proposal form defaults
	return opts
}

// OptsToPath converts scheduling options into a URL path with query parameters.
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
	if len(q) > 0 {
		return "?" + strings.Join(q, "&")
	}
	return ""
}

// Normalize converts a given path with query parameters into a normalized path using scheduling options.
func Normalize(path string) string {
	return OptsToPath(GetScheduleOpts(path))
}

// OptsWithKeyValue merges the provided key-value pair into the default options and any additional input options.
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

// WithTitle sets a custom title for the sessions section of an episode.
func WithoutTitle(opts ...map[string]any) map[string]any {
	return OptsWithKeyValue("SessionsTitle", "", opts...)
}

// WithTitle sets a custom title for the sessions section of an episode.
func WithSpeaker(opts ...map[string]any) map[string]any {
	return OptsWithKeyValue("Speaker", struct{}{}, opts...)
}

// ContentBlock is syntactic sugar for defining a single content block.
func ContentBlock(content string) *eve.Content {
	return &eve.Content{Published: true, Markdown: content}
}

// Nav is syntactic sugar for defining multiple content blocks for an episode.
func Nav(md ...string) []*eve.Content {
	var blocks []*eve.Content
	for _, m := range md {
		blocks = append(blocks, ContentBlock(m))
	}
	return blocks
}

// Writer is syntactic sugar for defining multiple EvtWriters for an episode.
func Writer(writers ...EvtWriter) []EvtWriter {
	return writers
}

// Keywords is syntactic sugar for defining keywords for an episode.
func Keywords(tags ...string) []string {
	return tags
}

// InDraft marks the event as a draft by clearing its start and end dates and appending " (draft)" to its name.
func InDraft(evt *event.Event, opts map[string]any) {
	evt.StartDate = time.Time{}
	evt.EndDate = time.Time{}
	evt.Name = evt.Name + " (draft)"
}

// PublishDraft finalizes a draft event by setting its start and end dates based on its sessions or defaulting to today if not set.
func PublishDraft(evt *event.Event, opts map[string]any) {
	// set start end time based on sessions default to today if not set
	if evt.StartDate.IsZero() || evt.EndDate.IsZero() {
		if len(evt.Sessions) > 0 {
			if !evt.Sessions[0].StartTime.IsZero() {
				evt.StartDate = evt.Sessions[0].StartTime
			}
			if !evt.Sessions[0].EndTime.IsZero() {
				evt.EndDate = evt.Sessions[0].EndTime
			}
		}
		if evt.StartDate.IsZero() {
			evt.StartDate = today()
		}
		if evt.EndDate.IsZero() {
			evt.EndDate = evt.StartDate.Add(1 * time.Hour)
		}
	}
	if strings.HasSuffix(evt.Name, " (draft)") {
		evt.Name = evt.Name[:len(evt.Name)-8]
	}
}

func today() time.Time {
	return time.Now().UTC().Truncate(24 * time.Hour)
}

func todayLink() string {
	d := today().Format("2006-01-02T15:04:05Z")
	return "?p=propose&status=EventScheduled&startDate=" + d + "&endDate=" + d
}
