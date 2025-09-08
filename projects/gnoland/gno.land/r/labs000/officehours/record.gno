package officehours

import (
    "strings"

    "gno.land/p/eve000/event"
    eve "gno.land/p/eve000/event/component"
    ufmt "gno.land/p/demo/ufmt"
)

type Record struct {
	Episode    func(map[string]any) *event.Event
	Content    []*eve.Content
	EvtWriters []EvtWriter // Yoneda move: objects are known by how they’re probed (the writers).
	Meta       []string
}

func (rec Record) RenderCalendar(path string) string {
    opts := GetScheduleOpts(path)
	evt := rec.Episode(WithSpeaker(opts))
	evt.SetRenderOpts(opts) // REVIEW: need to re-asses how opts used w/ nested data
	return evt.Render(path, eve.IcsCalendarFile)
}

func (rec Record) Compose(opts map[string]any) *event.Event {
    evt := rec.Episode(opts)
    for _, opSetter := range rec.EvtWriters {
        opSetter(evt, opts)
    }
    return evt
}

// TODO: refactor or rename
func (rec Record) Permalink(path string, opts map[string]interface{}) string {
	q := eve.ParseQuery(path)
	evt := rec.Compose(opts)
	cid := evt.Cid()

	// Build link with stable 8-char CID prefix and selected passthrough params.
	params := []string{
		"cid=" + cid[:8],
	}
	if v := q.Get("status"); v != "" {
		params = append(params, "status="+v)
	}
	if v := q.Get("startDate"); v != "" {
		params = append(params, "startDate="+v)
	}
	if v := q.Get("endDate"); v != "" {
		params = append(params, "endDate="+v)
	}

	link := ufmt.Sprintf("[permalink](?%s)", strings.Join(params, "&"))

	// If a cid= is provided, verify it matches the event's CID prefix.
	if provided := q.Get("cid"); provided != "" {
		prefixLen := 8
		if len(provided) < prefixLen {
			prefixLen = len(provided)
		}
		if len(cid) < prefixLen || cid[:prefixLen] != provided[:prefixLen] {
			return "\n> [!NOTE]\n> event details changed check for updates: " + link
		}
	}
	// TODO: actually wire this up to a form to make usable
	voteUpLink := ufmt.Sprintf("[vote↑up](?cid=%s&vote=up)", cid)
	voteDownLink := ufmt.Sprintf("[vote↓down](?cid=%s&vote=down)", cid)
	return "---\n" + link + " | " + voteUpLink + " | " + voteDownLink + "\n"
}

func (rec Record)Render(path string) string {
	q := eve.ParseQuery(path)
	var evt *event.Event
	page := q.Get("p")
	opts := GetScheduleOpts(path)

	switch page {
	case "json":
		evt = rec.Compose(WithSpeaker(opts))
		return "```json\n" + evt.Flyer().ToJson() + "\n```"

	case "calendar":
		evt = rec.Compose(WithSpeaker(opts))
		ics := evt.Render(path, eve.IcsCalendarFile)
		return "```" + ics + "```"

	case "speakers":
		evt = rec.Compose(WithSpeaker(opts))

	default:
		evt = rec.Compose(WithoutTitle(opts))
	}

	return evt.RenderContent(path, rec.Content) + "\n" + rec.Permalink(path, opts)
}
