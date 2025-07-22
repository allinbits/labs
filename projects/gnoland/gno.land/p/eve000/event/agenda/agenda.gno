package agenda

import (
	"net/url"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
)

type Agenda struct {
	Name           string
	Location       *location.Location
	StartDate      time.Time
	EndDate        time.Time
	Status         component.EventStatus
	AttendanceMode component.EventAttendanceMode
	Banner         *component.Content
	Description    string
	Sessions       []*session.Session
	renderOpts     map[string]interface{}
}

var _ component.Component = (*Agenda)(nil)

func FormatDate(date time.Time) string {
	if date.IsZero() {
		return ""
	}
	return date.Format(component.DtFmt)
}

func (a *Agenda) SetBanner(heading *component.Content) {
	a.Banner = heading
}

func (a *Agenda) ToAnchor() string {
	return component.StringToAnchor(a.Name)
}

func (a *Agenda) ToMarkdown(_ ...component.Content) string {
	markdown := "## " + a.Name + "\n\n"

	if _, ok := a.RenderOpts()["Location"]; ok && a.Location != nil {
		markdown += "### " + a.Location.Name + "\n\n"
	}

	if a.Status == component.EventScheduled {
		if FormatDate(a.StartDate) == FormatDate(a.EndDate) {
			markdown += FormatDate(a.StartDate) + "\n\n"
		} else {
			markdown += FormatDate(a.StartDate) + " - " + FormatDate(a.EndDate) + "\n\n"
		}
	}

	markdown += a.Description + "\n\n"

	if a.Banner != nil && a.Banner.Published {
		markdown += a.Banner.Markdown + "\n\n"
	}

	markdown += "## Agenda \n\n"

	// Group sessions by date
	sessionsByDate := make(map[string][]*session.Session)
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

func (a *Agenda) ToJson() string {
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

func (a *Agenda) ToSVG() string {
	y := 40
	fragment := a.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y)
	return component.SvgHeading("600", height) + fragment + "</svg>"
}

func (a *Agenda) ToSVGFragment(y *int) string {
	svg := "<rect width=\"100%\" height=\"100%\" fill=\"#eeeeee\" rx=\"15\"/>"
	svg += component.RenderSVGLine(y, "title", "", a.Name)
	*y += 10
	svg += component.RenderSVGLine(y, "subtitle", "", a.Location.Name)
	*y += 10
	if a.Status == component.EventCancelled {
		svg += component.RenderSVGLine(y, "text", "label", "Status: Canceled")
	}
	if a.Status != component.EventPostponed {
		if a.StartDate == a.EndDate {
			svg += component.RenderSVGLine(y, "text", "", FormatDate(a.StartDate))
		} else {
			svg += component.RenderSVGLine(y, "text", "", FormatDate(a.StartDate)+" - "+FormatDate(a.EndDate))
		}
	} else {
		label := strings.TrimPrefix(string(a.Status), "https://schema.org/")
		svg += component.RenderSVGLine(y, "text", "", "Status: "+label)
	}
	*y += 20
	svg += component.RenderSVGLine(y, "text", "", a.Description)
	*y += 40
	for _, s := range a.Sessions {
		svg += s.ToSVGFragment(y)
		*y += 20
	}
	return svg
}

func (a *Agenda) ToSvgDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(a.ToSVG())
}

func (a *Agenda) RenderOpts() map[string]interface{} {
	return a.renderOpts
}

func (a *Agenda) SetRenderOpts(opts map[string]interface{}) {
	a.renderOpts = opts
}

func (a *Agenda) FilteredMarkdown(tag string) string {
	markdown := "## " + component.TagToName(tag) + "\n\n"

	// Group sessions by date
	sessionsByDate := make(map[string][]*session.Session)
	for _, session := range a.Sessions {
		date := session.StartTime.Format(component.DtFmt)
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

	return markdown
}
