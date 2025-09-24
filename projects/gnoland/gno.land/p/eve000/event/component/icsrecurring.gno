package component

import (
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

func IcsRecurringCalendarFile(path string, opts map[string]any) string {
	now := time.Now().UTC()
	uid := ufmt.Sprintf("%d@gnoland", now.UnixNano())

	location, _ := opts["Location"].(string)
	if location == "" {
		location = "Online"
	}
	freq, _ := opts["Freq"].(string)
	if freq == "" {
		freq = "WEEKLY"
	}
	byDay, _ := opts["ByDay"].(string)
	if byDay == "" {
		byDay = "MO"
	}
	interval := "1"
	if v, ok := opts["Interval"]; ok {
		switch val := v.(type) {
		case string:
			interval = val
		case int:
			interval = ufmt.Sprintf("%d", val)
		}
	}
	until, _ := opts["Until"].(string)
	if until == "" {
		until = "20261231T000000Z"
	}

	rrule := ufmt.Sprintf("FREQ=%s;BYDAY=%s;INTERVAL=%s;UNTIL=%s", freq, byDay, interval, until)

	start, _ := opts["DtStart"].(string)
	if start == "" {
		start = now.Format("20060102T150405Z")
	}
	end := now.Add(1 * time.Hour).Format("20060102T160405Z")

	var b strings.Builder
	b.WriteString("BEGIN:VCALENDAR\r\n")
	b.WriteString("VERSION:2.0\r\n")
	b.WriteString("PRODID:-//gnoland//event//EN\r\n")
	b.WriteString("BEGIN:VEVENT\r\n")
	b.WriteString("UID:" + uid + "\r\n")
	b.WriteString("DTSTAMP:" + start + "\r\n")
	b.WriteString("DTSTART:" + start + "\r\n")
	b.WriteString("DTEND:" + end + "\r\n")
	b.WriteString("LOCATION:" + location + "\r\n")
	b.WriteString("RRULE:" + rrule + "\r\n")

	// Add EXDATEs for cancelled dates
	if exdates, ok := opts["ExDates"].([]string); ok {
		for _, exdate := range exdates {
			b.WriteString("EXDATE:" + exdate + "\r\n")
		}
	}

	b.WriteString("SUMMARY:Recurring Event\r\n")
	b.WriteString("END:VEVENT\r\n")
	b.WriteString("END:VCALENDAR\r\n")

	return b.String()
}