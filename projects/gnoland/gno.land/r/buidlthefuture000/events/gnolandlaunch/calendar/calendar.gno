package calendar

import (
	"net/url"
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event"
	"gno.land/r/buidlthefuture000/events/gnolandlaunch"
)

var f = ufmt.Sprintf

func ToICS() string {
	var b strings.Builder
	w := makeWriter(&b)

	w("BEGIN:VCALENDAR")
	w("VERSION:2.0")
	w("CALSCALE:GREGORIAN")
	w("PRODID:-//gno.land//Launch Calendar//EN")
	w("METHOD:PUBLISH")

	for _, s := range gnolandlaunch.LiveEvent().GetSessions() {
		b.WriteString(s.ToICSFragment())
	}

	w("END:VCALENDAR")
	return b.String()
}

func ToICSDataUrl() string {
	return "data:text/calendar;charset=utf-8," + url.PathEscape(ToICS())
}

func ToMarkdown() string {
	var b strings.Builder
	for _, s := range gnolandlaunch.LiveEvent().GetSessions() {
		b.WriteString(s.ToMarkdown())
	}
	return b.String()
}

func RenderCal(path string) string {
	var b strings.Builder
	w := makeWriter(&b)

	q := parseQuery(path)
	sessionIDs := q["session"]
	format := strings.ToLower(q.Get("format"))

	useAll := len(sessionIDs) == 0
	allowed := make(map[string]bool)
	for _, id := range sessionIDs {
		allowed[id] = true
	}
	include := func(id string) bool { return useAll || allowed[id] }

	sessions := gnolandlaunch.LiveEvent().GetSessions()

	switch format {
	case "json":
		b.WriteString("[")
		first := true
		for i, s := range sessions {
			id := event.Pad3(strconv.Itoa(i))
			if !include(id) {
				continue
			}
			if !first {
				b.WriteString(",")
			}
			first = false
			b.WriteString(s.ToJson())
		}
		b.WriteString("]")
		return b.String()

	case "csv":
		w("Title,Speaker,Start,End,Location")
		for i, s := range sessions {
			id := event.Pad3(strconv.Itoa(i))
			if !include(id) {
				continue
			}
			title := escapeCSV(s.Title)
			speaker := escapeCSV(s.Speaker.ToMarkdown())
			start := s.StartTime.Format("20060102T150000Z")
			end := s.EndTime.Format("20060102T150000Z")
			location := escapeCSV(s.Location.ToMarkdown())
			w(f("%s,%s,%s,%s,%s", title, speaker, start, end, location))
		}
		return b.String()

	case "ics":
		w("BEGIN:VCALENDAR")
		w("VERSION:2.0")
		w("CALSCALE:GREGORIAN")
		w("PRODID:-//gno.land//Launch Calendar//EN")
		w("METHOD:PUBLISH")
		for i, s := range sessions {
			id := event.Pad3(strconv.Itoa(i))
			if !include(id) {
				continue
			}
			b.WriteString(s.ToICSFragment())
		}
		w("END:VCALENDAR")
		return b.String()

	default: // markdown
		for i, s := range sessions {
			id := event.Pad3(strconv.Itoa(i))
			if !include(id) {
				continue
			}
			w(s.ToMarkdown())
		}
		return b.String()
	}
}

func Render(path string) string {
	return RenderCal(path)
}

func escapeCSV(s string) string {
	return `"` + strings.ReplaceAll(s, `"`, `""`) + `"`
}

func parseQuery(path string) url.Values {
	if len(path) > 0 && path[0] == '?' {
		u, err := url.Parse(std.CurrentRealm().PkgPath() + path)
		if err == nil {
			return u.Query()
		}
	}
	return url.Values{}
}

func makeWriter(b *strings.Builder) func(string) {
	return func(s string) {
		b.WriteString(s + "\n")
	}
}
