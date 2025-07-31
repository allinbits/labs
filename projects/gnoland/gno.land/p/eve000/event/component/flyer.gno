package component

import (
	"net/url"
	"std"
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

	if calHost, ok := a.RenderOpts()["CalendarHost"]; ok {
		fullURL := std.CurrentRealm().PkgPath() + "?format=ics"
		markdown += "[➕📅 Add to Calendar](" + calHost.(string) + "/" + fullURL + ")\n\n"
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

	return markdown
}

func (a *Flyer) ToJson() string {
	json := "{\n"
	json += "\"Name\":\"" + a.Name + "\",\n"
	json += "\"Location\":" + a.Location.ToJson() + ",\n"
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
	svg += RenderSVGLine(y, "subtitle", "", a.Location.Name)
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
