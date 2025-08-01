package component

import (
	"net/url"
	"regexp"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

type Flyer struct {
	Name           string
	Location       *Location
	StartDate      time.Time
	EndDate        time.Time
	Status         EventStatus
	AttendanceMode EventAttendanceMode
	Description    string
	Sessions       []*Session
	Images         []string
	renderOpts     map[string]interface{}
}

var _ Component = (*Flyer)(nil)

func FormatDate(date time.Time) string {
	if date.IsZero() {
		return ""
	}
	return date.Format(DtFmt)
}

func (a *Flyer) ToAnchor() string {
	return StringToAnchor(a.Name)
}

// ToMarkdown converts the Flyer to a Markdown representation (with optional additional content).
func (a *Flyer) ToMarkdown(body ...Content) string {
	markdown := "## " + a.Name + "\n\n"

	if _, ok := a.RenderOpts()["Location"]; ok && a.Location != nil {
		markdown += "### " + a.Location.Name + "\n\n"
	}

	if a.Status == EventScheduled {
		if FormatDate(a.StartDate) == FormatDate(a.EndDate) {
			markdown += FormatDate(a.StartDate) + "\n\n"
		} else {
			markdown += FormatDate(a.StartDate) + " - " + FormatDate(a.EndDate) + "\n\n"
		}
	}

	markdown += a.Description + "\n\n"
	fullURL := std.CurrentRealm().PkgPath()

	if calHost, ok := a.RenderOpts()["CalendarHost"]; ok {
		markdown += "[➕📅 Add to Calendar](" + calHost.(string) + "/" + fullURL + "?format=ics" + ")\n\n"
	}
	if calFile, ok := a.RenderOpts()["CalendarFile"]; ok {
		markdown += "[📥 Download Calendar File](" + calFile.(string) + "/" + fullURL + "?format=ics" + ")\n\n"
	}
	if _, ok := a.RenderOpts()["CalendarDataUrl"]; ok {
		markdown += "[📅 Calendar Data URL](" + a.CalenderDataUrl() + ")\n\n"
	}

	if len(body) > 0 {
		for _, content := range body {
			if content.Published {
				markdown += content.Render() + "\n\n"
			}
		}
	}

	markdown += "## Agenda \n\n"

	// Group sessions by date
	sessionsByDate := make(map[string][]*Session)
	for _, session := range a.Sessions {
		date := FormatDate(session.StartTime)
		sessionsByDate[date] = append(sessionsByDate[date], session)
	}

	// Generate markdown for each day
	for date, sessions := range sessionsByDate {
		markdown += "### " + date + "\n\n"
		for _, session := range sessions {
			markdown += session.ToMarkdown()
		}
	}

	// Collect unique speakers and locations
	var speakersMarkdown, locationsMarkdown string
	speakersSet := make(map[string]bool)
	locationsSet := make(map[string]bool)

	for _, session := range a.Sessions {
		// Collect unique speakers
		speakerMarkdown := session.Speaker.ToMarkdown()
		if !speakersSet[speakerMarkdown] {
			speakersSet[speakerMarkdown] = true
			speakersMarkdown += speakerMarkdown + "\n***\n"
		}

		// Collect unique locations
		locationMarkdown := session.Location.ToMarkdown()
		if !locationsSet[locationMarkdown] {
			locationsSet[locationMarkdown] = true
			locationsMarkdown += locationMarkdown + "\n***\n"
		}
	}

	if _, ok := a.RenderOpts()["Speaker"]; ok {
		markdown += "## Speakers\n\n" + speakersMarkdown
	}
	if _, ok := a.RenderOpts()["Location"]; ok {
		markdown += "## Locations\n\n" + locationsMarkdown
	}
	if _, ok := a.RenderOpts()["SvgFooter"]; ok {
		markdown += "[![Flyer SVG](" + a.ToSvgDataUrl() + ")](" + a.ToAnchor() + ")\n\n"
	}

	return markdown
}

func (a *Flyer) ToJson() string {
	json := "{\n"
	json += "\"Name\":\"" + a.Name + "\",\n"
	if a.Location != nil && a.Location.Name != "" {
		json += "\"Location\":" + a.Location.ToJson() + ",\n"
	}
	json += "\"StartDate\":\"" + FormatDate(a.StartDate) + "\",\n"
	json += "\"EndDate\":\"" + FormatDate(a.EndDate) + "\",\n"
	json += "\"Description\":\"" + a.Description + "\",\n"
	json += "\"Sessions\":[\n"
	for i, session := range a.Sessions {
		json += session.ToJson()
		if i < len(a.Sessions)-1 {
			json += ",\n"
		}
	}
	json += "\n]\n}"
	return json
}

func (a *Flyer) ToSVG() string {
	y := 40
	fragment := a.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y)
	return SvgHeading("600", height) + fragment + "</svg>"
}

func (a *Flyer) ToSVGFragment(y *int) string {
	svg := "<rect width=\"100%\" height=\"100%\" fill=\"#eeeeee\" rx=\"15\"/>"
	svg += RenderSVGLine(y, "title", "", a.Name)
	*y += 10
	if _, ok := a.RenderOpts()["Location"]; ok && a.Location != nil {
		svg += RenderSVGLine(y, "subtitle", "", a.Location.Name)
	}
	*y += 10
	if a.Status == EventCancelled {
		svg += RenderSVGLine(y, "text", "label", "Status: Canceled")
	}
	if a.Status != EventPostponed {
		if a.StartDate == a.EndDate {
			svg += RenderSVGLine(y, "text", "", FormatDate(a.StartDate))
		} else {
			svg += RenderSVGLine(y, "text", "", FormatDate(a.StartDate)+" - "+FormatDate(a.EndDate))
		}
	} else {
		label := strings.TrimPrefix(string(a.Status), "https://schema.org/")
		svg += RenderSVGLine(y, "text", "", "Status: "+label)
	}
	*y += 20
	svg += RenderSVGLine(y, "text", "", a.Description)
	*y += 40
	for _, s := range a.Sessions {
		svg += s.ToSVGFragment(y)
		*y += 20
	}
	return svg
}

func (a *Flyer) ToSvgDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(a.ToSVG())
}

func (a *Flyer) RenderOpts() map[string]interface{} {
	return a.renderOpts
}

func (a *Flyer) SetRenderOpts(opts map[string]interface{}) {
	a.renderOpts = opts
}

func (a *Flyer) CalenderDataUrl() string {
	data := a.RenderCalendar("?format=ics")
	return "data:text/calendar;charset=utf-8," + url.QueryEscape(data)
}

const DateFormatJsonLD = "2006-01-02T15:04:05-07:00"

func (a *Flyer) ToJsonLD() string {
	var sb strings.Builder
	sb.WriteString(`{
        "@context": "https://schema.org",
        "@type": "Event",
        "name": "` + ufmt.Sprintf("%s", a.Name) + `",`)

	if a.Status == EventPostponed {
		sb.WriteString(`
        "previousStartDate": "` + ufmt.Sprintf("%s", a.StartDate.Format(DateFormatJsonLD)) + `",`)
	} else {
		sb.WriteString(`
        "startDate": "` + ufmt.Sprintf("%s", a.StartDate.Format(DateFormatJsonLD)) + `",`)
		sb.WriteString(`
        "endDate": "` + ufmt.Sprintf("%s", a.EndDate.Format(DateFormatJsonLD)) + `",`)
	}

	sb.WriteString(`
        "eventAttendanceMode": "` + ufmt.Sprintf("%s", a.AttendanceMode) + `",
        "eventStatus": "` + ufmt.Sprintf("%s", a.Status) + `",`)

	if a.AttendanceMode != OfflineEventAttendanceMode && a.Location != nil {
		sb.WriteString(`
        "location": {
            "@type": "Place",
            "name": "` + ufmt.Sprintf("%s", a.Location.Name) + `"
        },`)
	}

	// Add images if available
	sb.WriteString(`
        "image": [`)
	for i, img := range a.Images {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString(`"` + ufmt.Sprintf("%s", img) + `"`)
	}
	sb.WriteString(`],`)

	sb.WriteString(`
        "description": "` + ufmt.Sprintf("%s", a.Description) + `"
    }`)
	return sb.String()
}

func (a *Flyer) RenderCalendar(path string) string {
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

func slugify(s string) string {
	re := regexp.MustCompile(`[^a-z0-9]+`)
	lower := strings.ToLower(s)
	slug := re.ReplaceAllString(lower, "-")
	return strings.Trim(slug, "-")
}

func Pad3(s string) string {
	for len(s) < 3 {
		s = "0" + s
	}
	return s
}
