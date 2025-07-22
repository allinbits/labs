package session

import (
	"net/url"
	"regexp"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/speaker"
)

type Session struct {
	Title       string
	Description string
	Speaker     *speaker.Speaker
	StartTime   time.Time
	EndTime     time.Time
	Location    *location.Location
	renderOpts  map[string]interface{}
	Sequence    int
	Cancelled   bool
}

var (
	_ component.Component = (*Session)(nil)
	f                     = ufmt.Sprintf
)

func (s *Session) SetTitle(title string) {
	s.Title = title
}

func (s *Session) SetDescription(description string) {
	s.Description = description
	s.Sequence++
}

func (s *Session) SetSpeaker(speaker *speaker.Speaker) {
	s.Speaker = speaker
	s.Sequence++
}

func (s *Session) SetStartTime(startTime time.Time) {
	s.StartTime = startTime
	s.Sequence++
}

func (s *Session) SetEndTime(endTime time.Time) {
	s.EndTime = endTime
	s.Sequence++
}

func (s *Session) SetLocation(location *location.Location) {
	s.Location = location
	s.Sequence++
}

func (s *Session) SetCancelled(cancelled bool) {
	s.Cancelled = cancelled
	s.Sequence++
}

func (s *Session) ToAnchor() string {
	return component.StringToAnchor(s.Title)
}

func (s *Session) ToMarkdown(_ ...component.Content) string {
	duration := s.EndTime.Sub(s.StartTime)
	markdown := "### " + s.Title + "\n\n"
	markdown += " " + s.StartTime.Format(time.Kitchen)
	markdown += "-> " + s.EndTime.Format(time.Kitchen)
	if _, ok := s.RenderOpts()["Speaker"]; ok && s.Speaker != nil && s.Speaker.Name != "" {
		markdown += " | [Speaker - " + s.Speaker.Name + "](" + s.Speaker.ToAnchor() + ")"
	}
	if _, ok := s.RenderOpts()["Location"]; ok && s.Location != nil {
		markdown += " | [Location - " + s.Location.Name + "](" + component.StringToAnchor(s.Location.Name) + ")\n"
	}

	markdown += "\n\n" + s.Description + "\n\n"
	markdown += "Duration: " + component.FormatDuration(duration) + "\n"
	return markdown
}

func (s *Session) ToJson() string {
	json := "{\n"
	json += "\"Location\":\"" + s.Location.Name + "\",\n"
	json += "\"Title\":\"" + s.Title + "\",\n"
	json += "\"Description\":\"" + s.Description + "\",\n"
	json += "\"StartTime\":\"" + s.StartTime.Format(time.RFC3339) + "\",\n"
	json += "\"EndTime\":\"" + s.EndTime.Format(time.RFC3339) + "\",\n"
	json += "\"Speaker\":{\n"
	json += "    \"Name\":\"" + s.Speaker.Name + "\",\n"
	json += "    \"Biography\":\"" + s.Speaker.Biography + "\",\n"
	json += "    \"Affiliation\":\"" + s.Speaker.Affiliation + "\",\n"
	if s.Speaker.PictureURL != "" {
		json += "    \"PictureURL\":\"" + s.Speaker.PictureURL + "\",\n"
	}
	json += "}}\n" // speaker
	return json
}

func (s *Session) ToSVG() string {
	y := 40
	fragment := s.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y+20)
	return component.SvgHeading("600", height) + fragment + "</svg>"
}

func (s *Session) ToSVGFragment(y *int) string {
	svg := "<g class=\"session\">"

	// Left column (speaker, times, location)
	leftY := *y
	svg += ufmt.Sprintf(`<text x="20" y="%d" class="speaker">Speaker: %s</text>`, leftY, s.Speaker.Name)
	leftY += 20
	svg += ufmt.Sprintf(`<text x="20" y="%d" class="text">Start Time: %s</text>`, leftY, s.StartTime.Format(time.Kitchen))
	leftY += 20
	svg += ufmt.Sprintf(`<text x="20" y="%d" class="text">End Time: %s</text>`, leftY, s.EndTime.Format(time.Kitchen))
	leftY += 20
	if _, ok := s.RenderOpts()["Location"]; ok && s.Location != nil {
		svg += ufmt.Sprintf(`<text x="20" y="%d" class="text">Location: %s</text>`, leftY, s.Location.Name)
		leftY += 20
	}

	// Right column (title, description)
	rightY := *y
	svg += ufmt.Sprintf(`<text x="200" y="%d" class="sessiontitle">%s</text>`, rightY, s.Title)
	rightY += 20
	descriptionLines := component.SplitText(s.Description, 50)
	for _, line := range descriptionLines {
		svg += ufmt.Sprintf(`<text x="200" y="%d" class="text">%s</text>`, rightY, line)
		rightY += 20
	}

	*y = func(a, b int) int {
		if a > b {
			return a
		}
		return b
	}(leftY, rightY)
	svg += "</g>"
	return svg
}

func (s *Session) ToSvgDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(s.ToSVG())
}

func (s *Session) ToICS() string {
	var vcalendar strings.Builder
	w := func(line string) { vcalendar.WriteString(line + "\n") }
	w("BEGIN:VCALENDAR")
	w("VERSION:2.0")
	w("CALSCALE:GREGORIAN")
	w("PRODID:-//gno.land//Session Calendar//EN")
	w("METHOD:PUBLISH\n")
	vcalendar.WriteString(s.ToICSFragment())
	w("END:VCALDENDAR")

	return vcalendar.String()
}

func (s *Session) ToICSFragment() string {
	var vevent strings.Builder
	w := func(line string) { vevent.WriteString(line + "\n") }

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

	return vevent.String()
}

func (s *Session) ToICSDataUrl() string {
	return "data:text/calendar;charset=utf-8," + url.PathEscape(s.ToICS())
}

func slugify(s string) string {
	re := regexp.MustCompile(`[^a-z0-9]+`)
	lower := strings.ToLower(s)
	slug := re.ReplaceAllString(lower, "-")
	return strings.Trim(slug, "-")
}

func (s *Session) RenderOpts() map[string]interface{} {
	return s.renderOpts
}

func (s *Session) SetRenderOpts(ro map[string]interface{}) {
	s.renderOpts = ro
}
