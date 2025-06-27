package agenda

import (
	"net/url"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
)

type Agenda struct {
	Name        string
	Location    *location.Location
	StartDate   time.Time
	EndDate     time.Time
	Banner      *component.Content
	Description string
	Sessions    []*session.Session
	renderOpts  *component.RenderOpts
}

var _ component.Component = (*Agenda)(nil)

func (a *Agenda) SetBanner(heading *component.Content) {
	a.Banner = heading
}

func (a *Agenda) ToAnchor() string {
	return component.StringToAnchor(a.Name)
}

func (a *Agenda) ToMarkdown() string {
	markdown := "## " + a.Name + "\n\n"

	if a.RenderOpts().Location {
		markdown += "### " + a.Location.Name + "\n\n"
	}
	if a.StartDate.Format(component.DtFmt) == a.EndDate.Format(component.DtFmt) {
		markdown += a.StartDate.Format(component.DtFmt) + "\n\n"
	} else {
		markdown += a.StartDate.Format(component.DtFmt) + " - " + a.EndDate.Format(component.DtFmt) + "\n\n"
	}
	markdown += a.Description + "\n\n"

	if a.Banner != nil && a.Banner.Published {
		markdown += a.Banner.Markdown + "\n\n"
	}

	markdown += "## Agenda \n\n"

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

	if a.RenderOpts().Speaker {
		markdown += "## Speakers\n\n" + speakersMarkdown
	}
	if a.RenderOpts().Location {
		markdown += "## Locations\n\n" + locationsMarkdown
	}

	return markdown
}

func (a *Agenda) ToJson() string {
	json := "{\n"
	json += "\"Name\":\"" + a.Name + "\",\n"
	json += "\"Location\":" + a.Location.ToJson() + ",\n"
	json += "\"StartDate\":\"" + a.StartDate.Format(time.RFC3339) + "\",\n"
	json += "\"EndDate\":\"" + a.EndDate.Format(time.RFC3339) + "\",\n"
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
	if a.StartDate.Format(component.DtFmt) == a.EndDate.Format(component.DtFmt) {
		svg += component.RenderSVGLine(y, "text", "", a.StartDate.Format(component.DtFmt))
	} else {
		svg += component.RenderSVGLine(y, "text", "", a.StartDate.Format(component.DtFmt)+" - "+a.EndDate.Format(component.DtFmt))
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

func (a *Agenda) RenderOpts() *component.RenderOpts {
	return a.renderOpts
}

func (a *Agenda) SetRenderOpts(opts *component.RenderOpts) {
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
