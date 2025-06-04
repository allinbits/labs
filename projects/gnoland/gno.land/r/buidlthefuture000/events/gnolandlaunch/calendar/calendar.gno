package calendar

import (
	"net/url"
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

func ToJSON() string {
	var sb strings.Builder
	sb.WriteString("[\n")

	total := len(event.Sessions)
	count := 0

	for _, sess := range event.Sessions {
		sb.WriteString(sess.ToJson())

		count++
		if count < total {
			sb.WriteString(",\n")
		}
	}
	sb.WriteString("]")
	return sb.String()
}

func Render(path string) string {
	// Render is a 3 Part Demo of the Calendar System

	// I.
	v1 := ToICS()
	url1 := "data:text/calendar;charset=utf-8," + url.PathEscape(v1)
	link1 := f("[Download v1 ICS](%s)", url1)

	// II.
	event.Sessions["generics"].SetDescription("Updated description!")

	v2 := ToICS()
	url2 := "data:text/calendar;charset=utf-8," + url.PathEscape(v2)
	link2 := f("[Download v2 ICS](%s)", url2)

	// III.
	event.Sessions["apis"].SetCancelled(true)
	v3 := ToICS()
	url3 := "data:text/calendar;charset=utf-8," + url.PathEscape(v3)
	link3 := f("[Download v3 ICS](%s)", url3)

	out := f(
		"## Calendar v1\n```ics\n%s\n```\n%s\n\n"+
			"## Calendar v2\n```ics\n%s\n```\n%s\n\n"+
			"## Calendar v3\n```ics\n%s\n```\n%s",
		v1, link1,
		v2, link2,
		v3, link3,
	)
	return out
}
