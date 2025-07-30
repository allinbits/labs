package event

import (
	"regexp"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/flyer"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
	"gno.land/p/eve000/event/speaker"
)

var _ component.EventSchedule = (*Event)(nil)
var _ component.Page = (*Event)(nil)

//var _ Api = (*Event)(nil)

type Api interface {
	AddOrganizer(addr std.Address)
	AddProposer(addr, sender std.Address)
	AddReviewer(addr, sender std.Address)
	AddSpeaker(addr std.Address)
	AdminRemoveRole(role string, addr std.Address)
	AdminSetRole(role string, addr std.Address)
	AssertAtLeastRole(role string, sender std.Address)
	HasRole(role string, addr std.Address) bool
	JoinAsAttendee()
	JoinWaitlist()
	ListRoles() []string
	RegisterEvent(evt *Event, opts map[string]interface{}) string
	RemoveOrganizer(addr std.Address)
	RemoveProposer(addr, sender std.Address)
	RemoveReviewer(addr, sender std.Address)
	RemoveSelfAsAttendee()
	RemoveSelfFromWaitlist()
	RemoveSpeaker(addr std.Address)
	Render(path string) string
	RenderAcl(path string) string
	RenderList(role string) string
	ResetRoles()
	RoleExists(role string) bool
	SetContent(key, markdown string)
	SetPatchLevel(level int)
	SetRoleHandler(role string, fn func(string) bool)
	UnsetRoleHandler(role string)
}

var f = ufmt.Sprintf

type Storage struct {
	Sessions  *avl.Tree
	Speakers  *avl.Tree
	Locations *avl.Tree
}

type Event struct {
	Name           string
	Location       *location.Location
	StartDate      time.Time
	EndDate        time.Time
	Description    string
	Sessions       []*session.Session
	Status         component.EventStatus
	AttendanceMode component.EventAttendanceMode
	Images         []string
	renderOpts     map[string]interface{}
	storage        *Storage
}

func (evt *Event) SetEventName(name string) {
	evt.Name = name
}

func (evt *Event) SetEventLocation(loc *location.Location) {
	evt.Location = loc
}

func (evt *Event) SetEventStartDate(startDate time.Time) {
	evt.StartDate = startDate
}

func (evt *Event) SetEventEndDate(endDate time.Time) {
	evt.EndDate = endDate
}

func (evt *Event) SetEventDescription(description string) {
	evt.Description = description
}

func (evt *Event) SetSessions(sessions []*session.Session) {
	evt.Sessions = sessions
}

func (evt *Event) AddSpeaker(s *speaker.Speaker) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Speakers == nil {
		evt.storage.Speakers = &avl.Tree{}
	}
	id := Pad3(strconv.Itoa(evt.storage.Speakers.Size()))
	evt.storage.Speakers.Set(AvlKey("speaker", id), s)
}

func (evt *Event) AddLocation(loc *location.Location) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Locations == nil {
		evt.storage.Locations = &avl.Tree{}
	}
	id := Pad3(strconv.Itoa(evt.storage.Locations.Size()))
	evt.storage.Locations.Set(AvlKey("location", id), loc)
}

func (evt *Event) AddSession(sess *session.Session) {
	if evt.storage == nil {
		evt.storage = &Storage{}
	}
	if evt.storage.Sessions == nil {
		evt.storage.Sessions = &avl.Tree{}
	}
	// TODO: maybe Pad3 can accept interface so extras stringconv isn't needed here
	id := Pad3(strconv.Itoa(evt.storage.Sessions.Size()))
	evt.storage.Sessions.Set(AvlKey("session", id), sess)
}

func (evt *Event) GetSpeaker(id string) *speaker.Speaker {
	s, ok := evt.storage.Speakers.Get(AvlKey("speaker", id))
	if !ok {
		panic("speaker not found: id=" + id)
	}
	return s.(*speaker.Speaker)
}

func (evt *Event) GetLocation(id string) *location.Location {
	l, ok := evt.storage.Locations.Get(AvlKey("location", id))
	if !ok {
		panic("location not found: id=" + id)
	}
	return l.(*location.Location)
}

func (evt *Event) GetSession(id string) *session.Session {
	s, ok := evt.storage.Sessions.Get(AvlKey("session", id))
	if !ok {
		panic("session not found: id=" + id)
	}
	return s.(*session.Session)
}

func (evt *Event) GetSessions() []*session.Session {
	if evt.storage == nil || evt.storage.Sessions == nil {
		return nil
	}
	var sessions []*session.Session
	evt.storage.Sessions.IterateByOffset(0, evt.storage.Sessions.Size(), func(_ string, val any) bool {
		s := val.(*session.Session)
		sessions = append(sessions, s)
		return false
	})
	return sessions
}
func (evt *Event) Flyer() component.Component {
	f := &flyer.Flyer{
		Name:        evt.Name,
		Location:    evt.Location,
		StartDate:   evt.StartDate,
		EndDate:     evt.EndDate,
		Status:      evt.Status,
		Description: evt.Description,
		Sessions:    evt.Sessions,
	}
	f.SetRenderOpts(evt.renderOpts)
	return f
}

func (evt *Event) RenderMarkdown(body ...component.Content) string {
	return evt.Flyer().ToMarkdown(body...)
}

func (evt *Event) RenderCalendar(path string) string {
	var b strings.Builder
	w := makeWriter(&b)

	q := component.ParseQuery(path)
	sessionIDs := q["session"]
	format := strings.ToLower(q.Get("format"))

	useAll := len(sessionIDs) == 0
	allowed := make(map[string]bool)
	for _, id := range sessionIDs {
		allowed[id] = true
	}
	include := func(id string) bool { return useAll || allowed[id] }

	sessions := evt.GetSessions()

	switch format {
	case "json":
		b.WriteString(evt.Flyer().ToJson())
		return b.String()

	case "ics":
		w("BEGIN:VCALENDAR")
		w("VERSION:2.0")
		w("CALSCALE:GREGORIAN")
		w("PRODID:-//gno.land//Launch Calendar//EN")
		w("METHOD:PUBLISH\n")

		w("BEGIN:VEVENT")
		w(f("UID:event-%s@%s", slugify(evt.Name), "gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar"))
		w("SEQUENCE:0")
		w(f("DTSTAMP:%s", time.Now().UTC().Format("20060102T150405Z")))
		w(f("DTSTART;VALUE=DATE:%s", evt.StartDate.Format("20060102")))
		w(f("DTEND;VALUE=DATE:%s", evt.StartDate.AddDate(0, 0, 1).Format("20060102"))) // 👈 Fix: DTEND is exclusive
		w(f("SUMMARY:%s", evt.Name))
		w(f("DESCRIPTION:%s", evt.Description))
		w(f("LOCATION:%s", evt.Location.Name))
		w("END:VEVENT\n")

		for i, s := range sessions {
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
		w(f("# %s\n\n%s", evt.Name, evt.Description))
		for i, s := range sessions {
			id := Pad3(strconv.Itoa(i))
			if !include(id) {
				continue
			}
			w(s.ToMarkdown())
		}
		return b.String()
	}
}

func makeWriter(b *strings.Builder) func(string) {
	return func(s string) {
		b.WriteString(s + "\n")
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

// build a key for the AVL tree like "event:123" "speaker:456" or "location:789"
func AvlKey(label string, id string) string {
	return Pad3(id)
}

// Event may not be a component (yet!) but it is where the render opts are stored.
func (evt *Event) RenderOpts() map[string]interface{} {
	return evt.renderOpts
}

func (evt *Event) SetRenderOpts(opts map[string]interface{}) {
	evt.renderOpts = opts
}

func (evt *Event) ToAnchor() string {
	return component.StringToAnchor(evt.Name)
}

const DateFormatJsonLD = "2006-01-02T15:04:05-07:00"

func (evt *Event) ToJson() string {
	var sb strings.Builder
	sb.WriteString(`{
        "@context": "https://schema.org",
        "@type": "Event",
        "name": "` + ufmt.Sprintf("%s", evt.Name) + `",`)

	if evt.Status == component.EventPostponed {
		sb.WriteString(`
        "previousStartDate": "` + ufmt.Sprintf("%s", evt.StartDate.Format(DateFormatJsonLD)) + `",`)
	} else {
		sb.WriteString(`
        "startDate": "` + ufmt.Sprintf("%s", evt.StartDate.Format(DateFormatJsonLD)) + `",`)
		sb.WriteString(`
        "endDate": "` + ufmt.Sprintf("%s", evt.EndDate.Format(DateFormatJsonLD)) + `",`)
	}

	sb.WriteString(`
        "eventAttendanceMode": "` + ufmt.Sprintf("%s", evt.AttendanceMode) + `",
        "eventStatus": "` + ufmt.Sprintf("%s", evt.Status) + `",`)

	if evt.AttendanceMode != component.OfflineEventAttendanceMode && evt.Location != nil {
		sb.WriteString(`
        "location": {
            "@type": "Place",
            "name": "` + ufmt.Sprintf("%s", evt.Location.Name) + `"
        },`)
	}

	// Add images if available
	sb.WriteString(`
        "image": [`)
	for i, img := range evt.Images {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString(`"` + ufmt.Sprintf("%s", img) + `"`)
	}
	sb.WriteString(`],`)

	sb.WriteString(`
        "description": "` + ufmt.Sprintf("%s", evt.Description) + `"
    }`)
	return sb.String()
}
