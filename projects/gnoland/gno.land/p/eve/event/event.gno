package event

import (
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve/event/agenda"
	"gno.land/p/eve/event/component"
	"gno.land/p/eve/event/location"
	"gno.land/p/eve/event/session"
	"gno.land/p/eve/event/speaker"
)

type Event struct {
	Name        string
	Location    *location.Location
	StartDate   time.Time
	EndDate     time.Time
	Description string
	Sessions    []*session.Session
	renderOpts  *component.RenderOpts
}

var _ component.Component = (*Event)(nil)

func (evt *Event) SetName(name string) {
	evt.Name = name
}

func (evt *Event) SetLocation(loc *location.Location) {
	evt.Location = loc
}

func (evt *Event) SetStartDate(startDate time.Time) {
	evt.StartDate = startDate
}

func (evt *Event) SetEndDate(endDate time.Time) {
	evt.EndDate = endDate
}

func (evt *Event) SetDescription(description string) {
	evt.Description = description
}

func (evt *Event) SetSessions(sessions []*session.Session) {
	evt.Sessions = sessions
}

func (evt *Event) Agenda() *agenda.Agenda {
	a := &agenda.Agenda{
		Name:        evt.Name,
		Location:    evt.Location,
		StartDate:   evt.StartDate,
		EndDate:     evt.EndDate,
		Description: evt.Description,
		Sessions:    evt.Sessions,
	}
	a.SetRenderOpts(evt.renderOpts)
	return a
}

// build a key for the AVL tree like "event:123" "speaker:456" or "location:789"
func AvlKey(label string, seq int) string {
	return ufmt.Sprintf("%s:%d", label, seq)
}

func (evt *Event) AddSession(duration string, delay ...string) *session.Session {
	startTime := evt.StartDate
	endTime := startTime.Add(component.ParseDuration(duration))

	if len(evt.Sessions) > 0 {
		startTime = evt.Sessions[len(evt.Sessions)-1].EndTime
	}

	for _, d := range delay {
		delayTime := component.ParseDuration(d)
		startTime = startTime.Add(delayTime)
		endTime = endTime.Add(delayTime)
	}

	s := &session.Session{
		Title:       "TBD",
		Description: "TBD",
		StartTime:   startTime,
		EndTime:     endTime,
		Speaker: &speaker.Speaker{
			Name: "TBD",
		},
		Location: &location.Location{
			Name:        "TBD",
			Description: "Gnowhere",
		},
	}
	evt.Sessions = append(evt.Sessions, s)
	return s
}

// Event may not be a component (yet!) but it is where the render opts are stored.
func (evt *Event) RenderOpts() *component.RenderOpts {
	return evt.renderOpts
}

func (evt *Event) SetRenderOpts(opts *component.RenderOpts) {
	evt.renderOpts = opts
}

func (evt *Event) ToAnchor() string {
	return component.StringToAnchor(evt.Name)
}

func (evt *Event) ToMarkdown() string {
	// REVIEW: will keynote block be rendered properly
	return evt.Agenda().ToMarkdown()
}

func (evt *Event) ToSvgDataUrl() string {
	return evt.Agenda().ToSvgDataUrl()
}

func (evt *Event) ToSVG() string {
	return evt.Agenda().ToSVG()
}

func (evt *Event) ToJson() string {
	return `{
    "@context": "https://schema.org",
    "@type": "Event",
    "name": "` + ufmt.Sprintf("%s", evt.Name) + `",
    "startDate": "` + ufmt.Sprintf("%s", evt.StartDate.Format("2006-01-02T15:04:05-07:00")) + `",
    "endDate": "` + ufmt.Sprintf("%s", evt.EndDate.Format("2006-01-02T15:04:05-07:00")) + `",
    "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode",
    "eventStatus": "https://schema.org/EventScheduled",
    "location": {
        "@type": "Place",
        "name": "` + ufmt.Sprintf("%s", evt.Location.Name) + `"
    },
    "image": [],
    "description": "` + ufmt.Sprintf("%s", evt.Description) + `"
}`
}
