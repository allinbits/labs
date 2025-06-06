package calendar

import (
	"net/url"
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
	event "gno.land/r/buidlthefuture000/events/gnolandlaunch"
)

var f = ufmt.Sprintf

func ToICS() string {
	var calendar strings.Builder

	w := func(line string) { calendar.WriteString(line + "\n") }
	w("BEGIN:VCALENDAR")
	w("VERSION:2.0")
	w("CALSCALE:GREGORIAN")
	w("PRODID:-//gno.land//Launch Calendar//EN")
	w("METHOD:PUBLISH\n\n")

	for _, s := range event.Sessions {
		calendar.WriteString(s.ToICSFragment())
	}

	w("END:VCALENDAR")

	return calendar.String()
}

func ToICSDataUrl() string {
	return "data:text/calendar;charset=utf-8," + url.PathEscape(ToICS())
}

func ToMarkdown() string {
	var calendar strings.Builder
	for _, sess := range event.Sessions {
		calendar.WriteString(sess.ToMarkdown())
	}
	return calendar.String()
}

func RenderCal(path string) string {
	var calendar strings.Builder
	w := func(line string) { calendar.WriteString(line + "\n") }

	var sessionIDs []string
	var format string
	if len(path) > 0 && path[0] == '?' {
		fullURL := std.CurrentRealm().PkgPath() + path
		if u, err := url.Parse(fullURL); err == nil {
			q := u.Query()
			sessionIDs = q["session"]
			format = q.Get("format")
		}
	}

	N := len(event.Sessions)
	var validIDs []int
	for _, idStr := range sessionIDs {
		idx, err := strconv.Atoi(idStr)
		if err != nil || idx < 0 || idx >= N {
			continue
		}
		validIDs = append(validIDs, idx)
	}
	if len(validIDs) == 0 {
		validIDs = make([]int, N)
		for i := 0; i < N; i++ {
			validIDs[i] = i
		}
	}

	switch strings.ToLower(format) {

	case "json":
		calendar.WriteString("[")
		first := true
		for _, idx := range validIDs {
			if !first {
				calendar.WriteString(",")
			}
			calendar.WriteString(event.GetSession(idx).ToJson())
			first = false
		}
		calendar.WriteString("]")
		return calendar.String()

	case "csv":
		w("Title,Speaker,Start,End,Location\n")
		for _, idx := range validIDs {
			sess := event.GetSession(idx)
			title := `"` + strings.ReplaceAll(sess.Title, `"`, `""`) + `"`
			speaker := `"` + strings.ReplaceAll(sess.Speaker.ToMarkdown(), `"`, `""`) + `"`
			start := sess.StartTime.Format("20060102T150000Z")
			end := sess.EndTime.Format("20060102T150000Z")
			location := `"` + strings.ReplaceAll(sess.Location.ToMarkdown(), `"`, `""`) + `"`

			w(f("%s,%s,%s,%s,%s", title, speaker, start, end, location))
		}
		return calendar.String()

	case "ics":
		w("BEGIN:VCALENDAR")
		w("VERSION:2.0")
		w("CALSCALE:GREGORIAN")
		w("PRODID:-//gno.land//Launch Calendar//EN")
		w("METHOD:PUBLISH\n\n")
		for _, idx := range validIDs {
			calendar.WriteString(event.GetSession(idx).ToICSFragment())
		}
		w("\nEND:VCALENDAR")
		return calendar.String()

	default: // "markdown"
		for _, idx := range validIDs {
			w(event.GetSession(idx).ToMarkdown())
		}
		return calendar.String()
	}
}

func Render(path string) string {
	return RenderCal(path)
}
