package calendar

import (
	"net/url"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

type CalendarEvent struct {
	Name        string
	Date        time.Time
	Description string
}

func (ce *CalendarEvent) ToMarkdown() string {
	markdown := "### " + ce.Name + "\n\n"
	markdown += ce.Date.Format("January 2, 2006") + "\n\n"
	markdown += ce.Description + "\n\n"
	return markdown
}

func RenderMarkdown(path string, target time.Time, events []CalendarEvent) string {
	_ = path // TODO: improve render params using path
	markdown := "\n\n"
	for _, event := range events {
		// only add if the event is in the target month
		if event.Date.Year() == target.Year() && event.Date.Month() == target.Month() {
			markdown += event.ToMarkdown()
		}
	}
	return markdown
}

func RenderCalendar(path string, events []CalendarEvent) string {
	target := time.Now()
	if path == "" {
		path = "?year=" + ufmt.Sprintf("%d", target.Year()) + "&month=" + ufmt.Sprintf("%s", target.Month().String())
	} else {
		var year int
		var monthStr string
		parts := strings.Split(path, "&")
		for _, part := range parts {
			if strings.HasPrefix(part, "?year=") {
				year, _ = strconv.Atoi(strings.TrimPrefix(part, "?year="))
			} else if strings.HasPrefix(part, "month=") {
				monthStr = strings.TrimPrefix(part, "month=")
			}
		}
		if year != 0 && monthStr != "" {
			month, _ := time.Parse("January", monthStr)
			target = time.Date(year, month.Month(), 1, 0, 0, 0, 0, time.UTC)
		}
	}

	prevMonth := target.AddDate(0, -1, 0)
	nextMonth := target.AddDate(0, 1, 0)
	svg := GenerateSVGCalendar(target.Year(), target.Month(), events)
	out := "## " + target.Format("January 2006") + "\n\n"
	out += "[<- Previous](?year=" + ufmt.Sprintf("%d", prevMonth.Year()) + "&month=" + ufmt.Sprintf("%s", prevMonth.Month().String()) + ")\n"
	out += "[Next ->](?year=" + ufmt.Sprintf("%d", nextMonth.Year()) + "&month=" + ufmt.Sprintf("%s", nextMonth.Month().String()) + ")\n\n"
	out += "![Calendar](data:image/svg+xml;utf8," + url.PathEscape(svg) + ")"
	out += "\n\n" + RenderMarkdown(path, target, events)
	return out
}

func GenerateSVGCalendar(year int, month time.Month, events []CalendarEvent) string {
	firstOfMonth := time.Date(year, month, 1, 0, 0, 0, 0, time.UTC)
	firstWeekday := int(firstOfMonth.Weekday()) // Sunday = 0
	daysInMonth := daysIn(month, year)
	today := time.Now()

	// SVG constants
	cellWidth, cellHeight := 100, 80
	svgWidth, svgHeight := cellWidth*7, cellHeight*6+50

	var b strings.Builder
	b.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">`, svgWidth, svgHeight))
	b.WriteString(`<style>
        text { font-family: Arial, sans-serif; }
        .day { fill: #f0f0f0; stroke: #ccc; }
        .header { fill: #d0e0ff; stroke: #999; font-weight: bold; }
        .date { font-size: 14px; text-anchor: middle; dominant-baseline: middle; }
        .highlight { fill: #ffeb3b; }
        .today { fill: none; stroke: #aaa; stroke-width: 2; }
        .today_date { font-size: 18px; text-anchor: middle; dominant-baseline: middle; fill: #000; }
    </style>`)

	// Weekday headers
	weekdays := []string{"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
	for i, day := range weekdays {
		x, y := i*cellWidth, 0
		b.WriteString(ufmt.Sprintf(`<rect class="header" x="%d" y="%d" width="%d" height="50"/>`, x, y, cellWidth))
		b.WriteString(ufmt.Sprintf(`<text class="date" x="%d" y="%d">%s</text>`, x+cellWidth/2, y+25, day))
	}

	// Draw the grid & dates
	dayNum := 1
	for week := 0; week < 6; week++ {
		for weekday := 0; weekday < 7; weekday++ {
			x := weekday * cellWidth
			y := week*cellHeight + 50

			// Check if the current day is in the events slice
			currentDate := time.Date(year, month, dayNum, 0, 0, 0, 0, time.UTC)
			isHighlighted := false
			for _, event := range events {
				if event.Date.Equal(currentDate) {
					isHighlighted = true
					break
				}
			}

			if isHighlighted {
				b.WriteString(ufmt.Sprintf(`<rect class="day highlight" x="%d" y="%d" width="%d" height="%d"/>`, x, y, cellWidth, cellHeight))
			} else {
				b.WriteString(ufmt.Sprintf(`<rect class="day" x="%d" y="%d" width="%d" height="%d"/>`, x, y, cellWidth, cellHeight))
			}

			// Skip cells before first day
			if week == 0 && weekday < firstWeekday || dayNum > daysInMonth {
				continue
			}

			// Draw today's date circle
			if currentDate.Year() == today.Year() && currentDate.Month() == today.Month() && currentDate.Day() == today.Day() {
				b.WriteString(ufmt.Sprintf(`<circle class="today" cx="%d" cy="%d" r="20"/>`, x+cellWidth/2, y-2+cellHeight/2))
				b.WriteString(ufmt.Sprintf(`<text class="today_date" x="%d" y="%d">%d</text>`, x+cellWidth/2, y+cellHeight/2, dayNum))
			} else {
				b.WriteString(ufmt.Sprintf(`<text class="date" x="%d" y="%d">%d</text>`, x+cellWidth/2, y+cellHeight/2, dayNum))
			}

			dayNum++
		}
	}

	b.WriteString(`</svg>`)
	return b.String()
}
func daysIn(m time.Month, year int) int {
	return time.Date(year, m+1, 0, 0, 0, 0, 0, time.UTC).Day()
}
