package officehours

import (
	"strings"

	ufmt "gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
	logo "gno.land/r/labs000/logoverse"
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

func (rec Record) Render(path string) string {
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

	return evt.RenderContent(path, rec.Content) + "\n" + rec.BottomNav(path, opts)
}

func (rec Record) BottomNav(path string, opts map[string]interface{}) string {
	cidLen := 8
	q := eve.ParseQuery(path)
	evt := rec.Compose(opts)
	cid := evt.Cid()

	// Build link with stable 16-char CID suffix and selected passthrough params.
	params := []string{
		"cid=" + cid[len(cid)-cidLen:],
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

	permalink := ufmt.Sprintf("?%s", strings.Join(params, "&"))
	link := ufmt.Sprintf("[permalink](?%s)", permalink)

	// If a cid= is provided, verify it matches the event's CID suffix.
	if provided := q.Get("cid"); provided != "" {
		if len(provided) < cidLen {
			cidLen = len(provided)
		}
		if len(cid) < cidLen || cid[len(cid)-cidLen:] != provided[len(provided)-cidLen:] {
			return "\n> [!NOTE]\n> event details changed check for updates: " + link
		}
	}
	voteUpLink := ufmt.Sprintf("[vote↑up](" + permalink + "&vote=up)")
	voteDownLink := ufmt.Sprintf("[vote↓down](" + permalink + "&vote=down)")
	proposeLink := ufmt.Sprintf("[propose](/r/labs000/officehours/season001/episode000" + todayLink() + ")")

	return "\n[" + logo.AllInBits.Thumbnail() + "](/r/labs000/officehours) \n\n " +
		link + " | " + voteUpLink + " | " + voteDownLink + " | " + proposeLink
}
