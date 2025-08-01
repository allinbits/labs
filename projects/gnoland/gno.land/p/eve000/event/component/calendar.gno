package component

import (
	"net/url"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

func CalenderDataUrl(path string, a *Flyer) string {
	if path == "" {
		path = "?format=ics"
	}
	data := IcsCalendarFile(path, a)
	return "data:text/calendar;charset=utf-8," + url.QueryEscape(data)
}

func IcsCalendarFile(path string, a *Flyer) string {
	var f = ufmt.Sprintf
	var b strings.Builder
	w := func(s string) {
		b.WriteString(s + "\n")
	}

	q := ParseQuery(path)
	sessionIDs := q["session"]
	format := strings.ToLower(q.Get("format"))

	useAll := len(sessionIDs) == 0
	allowed := make(map[string]bool)
	for _, id := range sessionIDs {
		allowed[id] = true
	}
	include := func(id string) bool { return useAll || allowed[id] }

	switch format {
	case "json":
		b.WriteString(a.ToJson())
		return b.String()

	case "ics":
		w("BEGIN:VCALENDAR")
		w("VERSION:2.0")
		w("CALSCALE:GREGORIAN")
		w("PRODID:-//gno.land//Launch Calendar//EN")
		w("METHOD:PUBLISH\n")

		w("BEGIN:VEVENT")
		w(f("UID:event-%s@%s", slugify(a.Name), "gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar"))
		w("SEQUENCE:0")
		w(f("DTSTAMP:%s", time.Now().UTC().Format("20060102T150405Z")))
		w(f("DTSTART;VALUE=DATE:%s", a.StartDate.Format("20060102")))
		w(f("DTEND;VALUE=DATE:%s", a.StartDate.AddDate(0, 0, 1).Format("20060102"))) // 👈 Fix: DTEND is exclusive
		w(f("SUMMARY:%s", a.Name))
		w(f("DESCRIPTION:%s", a.Description))
		if a.Location != nil && a.Location.Name != "" {
			w(f("LOCATION:%s", a.Location.Name))
		}
		w("END:VEVENT\n")

		for i, s := range a.Sessions {
			id := Pad3(strconv.Itoa(i))
			if !include(id) {
				continue
			}

			w("BEGIN:VEVENT")
			w(f("UID:%s-%d@%s",
				slugify(s.Title)[:5],
				s.StartTime.Unix(),
				"gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar",
			))
			w(f("SEQUENCE:%d", s.Sequence))
			w(f("DTSTAMP:%s", time.Now().UTC().Format("20060102T150405Z")))
			w(f("DTSTART:%s", s.StartTime.UTC().Format("20060102T150000Z")))
			w(f("DTEND:%s", s.EndTime.UTC().Format("20060102T150000Z")))
			w(f("SUMMARY:%s", s.Title))
			w(f("DESCRIPTION:%s", s.Description))
			w(f("LOCATION:%s", s.Location.Name))
			if s.Cancelled {
				w("STATUS:CANCELLED")
			}
			w("END:VEVENT\n")
		}

		w("END:VCALENDAR")
		return b.String()

	default:
		w(f("# %s\n\n%s", a.Name, a.Description))
		for i, s := range a.Sessions {
			id := Pad3(strconv.Itoa(i))
			if !include(id) {
				continue
			}
			w(s.ToMarkdown())
		}
		return b.String()
	}
}
