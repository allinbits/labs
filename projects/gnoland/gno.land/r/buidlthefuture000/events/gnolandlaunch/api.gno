package event

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/register"
	"gno.land/p/eve000/event/speaker"
)

var (
	eventRegistry    *EventRegistry // liveEventId is the ID of the currently live event.
	realmAllowPrefix = []string{}   // realms prefixes that have access to update the registry
	registry         *register.Registry
	staticContent    = &component.Content{
		Published: false,
		Markdown:  "This page has been disabled",
	}
	eventMap = &component.Content{
		Published: false,
		Markdown:  "This page has been disabled",
	}
	keynoteHeading = &component.Content{
		Published: false,
		Markdown:  `#### Keynote\n\n TODO: update with patch001`,
	}
	renderOpts = &component.RenderOpts{
		Location: true,
		Svg:      true,
		Schedule: true,
		Speaker:  false,
	}
	const gopherconICS = `BEGIN:VCALENDAR
	VERSION:2.0
	CALSCALE:GREGORIAN
	PRODID:-//gno.land//GopherCon 2025//EN
	X-WR-CALNAME:GopherCon 2025
	X-WR-TIMEZONE:UTC
	METHOD:PUBLISH

	BEGIN:VEVENT
	UID:Generics i-20250516T150000Z@gno.land/r/eve/events/gophercon
	DTSTAMP:20250516T150000Z
	SUMMARY:Generics in Action: Simplifying Go Code
	DESCRIPTION:Learn practical use cases for Go generics to simplify and enhance your code.
	DTSTART:20250517T100000Z
	DTEND:20250517T113000Z
	LOCATION:Room A1
	END:VEVENT

	BEGIN:VEVENT
	UID:Concurrenc-20250516T150000Z@gno.land/r/eve/events/gophercon
	DTSTAMP:20250516T150000Z
	SUMMARY:Concurrency Patterns in Real-World Applications
	DESCRIPTION:A deep dive into concurrency patterns to efficiently handle complex workflows.
	DTSTART:20250517T130000Z
	DTEND:20250517T143000Z
	LOCATION:Room B2
	END:VEVENT

	BEGIN:VEVENT
	UID:Building H-20250516T150000Z@gno.land/r/eve/events/gophercon
	DTSTAMP:20250516T150000Z
	SUMMARY:Building High-Performance APIs with Go
	DESCRIPTION:Techniques and best practices for building scalable and performant APIs.
	DTSTART:20250517T150000Z
	DTEND:20250517T163000Z
	LOCATION:Room C3
	END:VEVENT

	END:VCALENDAR
	`
)

type EventRegistry struct {
	LiveEventId int
	PatchLevel  int
}

func (er *EventRegistry) SetPatchLevel(level int) {
	if level != er.PatchLevel+1 {
		panic("patch level must be incremented by 1")
	}
	er.PatchLevel = level
}

func (er *EventRegistry) SetLiveEventId(id int) {
	er.LiveEventId = id
}

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/patch")
	registry = register.NewRegistry(renderOpts)
	eventRegistry = &EventRegistry{
		LiveEventId: registry.RegisterEvent(gopherCon2025),
		PatchLevel:  0,
	}
}

type VEvent struct {
	UID         string
	DtStamp     string
	Summary     string
	Description string
	DtStart     string
	DtEnd       string
	Location    string
}

type VCalendar struct {
	ProdID    string
	CalName   string
	TimeZone  string
	Method    string
	Events    []VEvent
}

func ToRFC5545(e *event.Event) string {
	vc := VCalendar{
		ProdID:   fmt.Sprintf("-//gno.land//%s//EN", e.Name),
		CalName:  e.Name,
		TimeZone: "UTC",
		Method:   "PUBLISH",
	}

	now := time.Now().UTC().Format("20060102T150405Z")

	for _, s := range e.Sessions {
		prefix := s.Title
		if len(prefix) > 10 {
			prefix = prefix[:10]
		}
		uid := fmt.Sprintf("%s-%s@gno.land/r/eve/events/gophercon", prefix, now)

		evt := VEvent{
			UID:         uid,
			DtStamp:     now,
			Summary:     s.Title,
			Description: s.Description,
			DtStart:     s.StartTime.UTC().Format("20060102T150405Z"),
			DtEnd:       s.EndTime.UTC().Format("20060102T150405Z"),
			Location:    s.Location.Name,
		}
		vc.Events = append(vc.Events, evt)
	}

	var b strings.Builder
	b.WriteString("BEGIN:VCALENDAR\n")
	b.WriteString("VERSION:2.0\n")
	b.WriteString("CALSCALE:GREGORIAN\n")
	b.WriteString(fmt.Sprintf("PRODID:%s\n", vc.ProdID))
	b.WriteString(fmt.Sprintf("X-WR-CALNAME:%s\n", vc.CalName))
	b.WriteString(fmt.Sprintf("X-WR-TIMEZONE:%s\n", vc.TimeZone))
	b.WriteString(fmt.Sprintf("METHOD:%s\n\n", vc.Method))

	for _, ev := range vc.Events {
		b.WriteString("BEGIN:VEVENT\n")
		b.WriteString(fmt.Sprintf("UID:%s\n", ev.UID))
		b.WriteString(fmt.Sprintf("DTSTAMP:%s\n", ev.DtStamp))
		b.WriteString(fmt.Sprintf("SUMMARY:%s\n", ev.Summary))
		b.WriteString(fmt.Sprintf("DESCRIPTION:%s\n", ev.Description))
		b.WriteString(fmt.Sprintf("DTSTART:%s\n", ev.DtStart))
		b.WriteString(fmt.Sprintf("DTEND:%s\n", ev.DtEnd))
		b.WriteString(fmt.Sprintf("LOCATION:%s\n", ev.Location))
		b.WriteString("END:VEVENT\n\n")
	}
	b.WriteString("END:VCALENDAR")
	return b.String()
}

func Render(path string) (out string) {
	if staticContent.Published && path == "" {
		return staticContent.Markdown
	}
	id := getIdFromPath(path)
	switch {
	case strings.HasPrefix(path, "location:"):
		return component.RenderComponent(path, registry.GetLocation(id))
	case strings.HasPrefix(path, "speaker:"):
		return component.RenderComponent(path, registry.GetSpeaker(id))
	case strings.HasPrefix(path, "session:"):
		return component.RenderComponent(path, registry.GetSession(id))
	case strings.HasPrefix(path, "event:"): // render event obj
		evt := registry.GetEvent(id)
		if evt.Name == "" {
			panic(ufmt.Sprintf("error: event with id %d not found", id))
		}
		return component.RenderComponent(path, evt)
	case path == "":
		var LandingPage strings.Builder
		LandingPage.WriteString(keynoteHeading.Markdown + "\n\n")
		LandingPage.WriteString(component.RenderComponent(path, registry.GetEvent(id).Agenda()))
		LandingPage.WriteString(ufmt.Sprintf("[➕ Add GopherCon to your calendar](%s)\n\n", url.QueryEscape(gopherconICS)))
		return LandingPage.String()
	default:
		panic("invalid path")
	}
}

func getIdFromPath(path string) int {
	switch {
	case strings.HasPrefix(path, "event:"),
		strings.HasPrefix(path, "location:"),
		strings.HasPrefix(path, "speaker:"),
		strings.HasPrefix(path, "session:"):
		return component.IdFromPath(path)
	default:
		return eventRegistry.LiveEventId
	}
}

// Info returns a formatted string with the message and path
// including the liveEventId for debugging purposes.
func info(opts ...string) string {
	msg := "info: "
	path := ""
	if len(opts) == 1 {
		msg = opts[0]
	} else if len(opts) == 2 {
		msg = opts[0]
		path = opts[1]
	}
	return ufmt.Sprintf("%s\n\nliveEvent: %d\n\npath: %v", msg, eventRegistry.LiveEventId, path)
}

/* Content Management API */
func Publish(markdown string) {
	AssertAdminAccess()
	staticContent.Published = true
	staticContent.Markdown = markdown
}

func Destroy(markdown string) {
	Publish(markdown)
	registry = register.NewRegistry(renderOpts) // reset the registry to a new instance
}

func Revision() string {
	patchLevelStr := strconv.Itoa(eventRegistry.PatchLevel)
	if eventRegistry.PatchLevel < 10 {
		patchLevelStr = "00" + patchLevelStr
	} else if eventRegistry.PatchLevel < 100 {
		patchLevelStr = "0" + patchLevelStr
	}
	return "\n\n[rev: " + strconv.Itoa(eventRegistry.PatchLevel) + "](./gophercon/patch" + patchLevelStr + ")\n\n"
}

func Unpublish(key string) {
	AssertAdminAccess()
	switch key {
	case "map":
		eventMap.Published = false
	case "published":
		staticContent.Published = false
	case "keynote":
		keynoteHeading.Published = false
	default:
		panic("invalid key: " + key)
	}
}

func SetContent(key, markdown string) {
	AssertAdminAccess()
	switch key {
	case "map":
		eventMap.SetPublished(true)
		eventMap.SetMarkdown(markdown)
	case "published":
		staticContent.SetPublished(true)
		staticContent.SetMarkdown(markdown)
	case "keynote":
		keynoteHeading.SetPublished(true)
		keynoteHeading.SetMarkdown(markdown)
	default:
		panic("invalid key: " + key)
	}
}

/* Render Management API */
func ToggleOpts(opts ...string) {
	AssertAdminAccess()
	for _, opt := range opts {
		switch opt {
		case "location":
			renderOpts.Location = !renderOpts.Location
		case "svg":
			renderOpts.Svg = !renderOpts.Svg
		case "schedule":
			renderOpts.Schedule = !renderOpts.Schedule
		case "content":
			staticContent.Published = !staticContent.Published
		case "map":
			eventMap.Published = !eventMap.Published
		case "speaker":
			renderOpts.Speaker = !renderOpts.Speaker
		default:
			panic("invalid option: " + opt)
		}
	}
}

func SetPatchLevel(level int) {
	AssertAdminAccess()
	if level != eventRegistry.PatchLevel+1 {
		panic("patch level must be incremented by 1")
	}
	eventRegistry.SetPatchLevel(level)
}

func LiveEventId() int {
	return eventRegistry.LiveEventId
}

func SetLiveEvent(id int) {
	AssertAdminAccess()
	eventRegistry.SetLiveEventId(id)
}

/* Auth API */
func HasAllowedPrefix() bool {
	currentRealm := std.CurrentRealm()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(currentRealm.PkgPath(), callerPath) {
			return true
		}
	}
	return false
}

func AssertAdminAccess() {
	if !HasAllowedPrefix() {
		panic("access denied: " + std.CurrentRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}

/* Speaker API */
func AddSpeaker() int {
	AssertAdminAccess()
	return registry.AddSpeaker(&speaker.Speaker{
		Name:        "New Speaker",
		Biography:   "Enter a short biography here.",
		Affiliation: "Company or Organization",
		PictureURL:  "https://avatars.githubusercontent.com/u/243500?s=400&u=fc288b7371b31b282885fd246ad09c168b96a6dc&v=4",
	})
}

func SetSpeakerName(id int, name string) {
	AssertAdminAccess()
	registry.GetSpeaker(id).SetName(name)
}

func SetSpeakerBiography(id int, bio string) {
	AssertAdminAccess()
	registry.GetSpeaker(id).SetBiography(bio)
}

func SetSpeakerAffiliation(id int, aff string) {
	AssertAdminAccess()
	registry.GetSpeaker(id).SetAffiliation(aff)
}

func SetSpeakerPictureURL(id int, url string) {
	AssertAdminAccess()
	registry.GetSpeaker(id).SetPictureURL(url)
}

/* Location API */
func AddLocation() int {
	AssertAdminAccess()
	return registry.AddLocation(&location.Location{
		Name:        "New Location",
		Address:     "Enter the address here.",
		Coordinates: "Enter the coordinates here.",
	})
}

func SetLocationName(id int, name string) {
	AssertAdminAccess()
	registry.GetLocation(id).SetName(name)
}

func SetLocationAddress(id int, address string) {
	AssertAdminAccess()
	registry.GetLocation(id).SetAddress(address)
}

func SetLocationDescription(id int, desc string) {
	AssertAdminAccess()
	registry.GetLocation(id).SetDescription(desc)
}

func SetLocationCoordinates(id int, coords string) {
	AssertAdminAccess()
	registry.GetLocation(id).SetCoordinates(coords)
}

/* Session API */
func SetSessionLocation(id int, loc *location.Location) {
	AssertAdminAccess()
	registry.GetEventSession(eventRegistry.LiveEventId, id).SetLocation(loc)
}

func SetSessionSpeaker(id int, spk *speaker.Speaker) {
	AssertAdminAccess()
	registry.GetEventSession(eventRegistry.LiveEventId, id).SetSpeaker(spk)
}

func SetSessionStartTime(id int, time string) {
	AssertAdminAccess()
	registry.GetEventSession(eventRegistry.LiveEventId, id).SetStartTime(component.ParseTime(time))
}

func SetSessionEndTime(id int, time string) {
	AssertAdminAccess()
	registry.GetEventSession(eventRegistry.LiveEventId, id).SetEndTime(component.ParseTime(time))
}

func SetSessionTitle(id int, title string) {
	AssertAdminAccess()
	registry.GetEventSession(eventRegistry.LiveEventId, id).SetTitle(title)
}

func SetSessionDescription(id int, desc string) {
	AssertAdminAccess()
	registry.GetEventSession(eventRegistry.LiveEventId, id).SetDescription(desc)
}

/* Event API */
func AddEvent(name, loc, startDate, endDate, description string) int {
	AssertAdminAccess()
	evt := &event.Event{
		Name:        name,
		Location:    &location.Location{Name: loc},
		StartDate:   component.ParseDate(startDate),
		EndDate:     component.ParseDate(endDate),
		Description: description,
	}
	evt.SetRenderOpts(renderOpts)
	registry.Storage.Events.Set(event.AvlKey("event", registry.EventSeq), evt)
	registry.IncrementEventSeq()
	return registry.EventSeq - 1
}

func SetEventName(id int, name string) {
	AssertAdminAccess()
	registry.GetEvent(id).SetName(name)
}

func SetEventLocation(id int, loc int) {
	AssertAdminAccess()
	registry.GetEvent(id).SetLocation(registry.GetLocation(loc))
}

func SetEventStartDate(id int, date string) {
	AssertAdminAccess()
	registry.GetEvent(id).SetStartDate(component.ParseTime(date))
}

func SetEventEndDate(id int, date string) {
	AssertAdminAccess()
	registry.GetEvent(id).SetEndDate(component.ParseTime(date))
}

func SetEventDescription(id int, desc string) {
	AssertAdminAccess()
	registry.GetEvent(id).SetDescription(desc)
}

func AddEventSession(eventId int, duration string, delay ...string) int {
	AssertAdminAccess()
	s := registry.GetEvent(eventId).AddSession(duration, delay...)
	registry.AddSession(s)
	registry.AddSpeaker(s.Speaker)
	registry.AddLocation(s.Location)
	return len(registry.GetEvent(eventId).Sessions) - 1
}

func SetEventSessionTitle(eventId, sessionId int, title string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).SetTitle(title)
}

func SetEventSessionDescription(eventId, sessionId int, desc string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).SetDescription(desc)
}

func SetEventSessionSpeaker(eventId, sessionId, speakerId int) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).SetSpeaker(registry.GetSpeaker(speakerId))
}

func SetEventSessionLocation(eventId, sessionId, locationId int) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).SetLocation(registry.GetLocation(locationId))
}

func SetEventSessionStartTime(eventId, sessionId int, time string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).SetStartTime(component.ParseTime(time))
}

func SetEventSessionEndTime(eventId, sessionId int, time string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).SetEndTime(component.ParseTime(time))
}

func SetEventSpeakerName(eventId int, sessionId int, name string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).Speaker.SetName(name)
}

func SetEventSpeakerBiography(eventId int, sessionId int, bio string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).Speaker.SetBiography(bio)
}

func SetEventSpeakerAffiliation(eventId int, sessionId int, aff string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).Speaker.SetAffiliation(aff)
}

func SetEventSpeakerPictureURL(eventId int, sessionId int, url string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).Speaker.SetPictureURL(url)
}

func SetEventLocationName(eventId int, sessionId int, loc string) {
	AssertAdminAccess()
	registry.GetEvent(eventId).Sessions[sessionId].Location.SetName(loc)
}

func SetEventLocationDescription(eventId int, sessionId int, desc string) {
	AssertAdminAccess()
	registry.GetEvent(eventId).Sessions[sessionId].Location.SetDescription(desc)
}

func SetEventLocationCoordinates(eventId int, sessionId int, coords string) {
	AssertAdminAccess()
	registry.GetEvent(eventId).Sessions[sessionId].Location.SetCoordinates(coords)
}

/* Tags API */
func SetSpeakerTags(eventId, sessionId int, tags ...string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).Speaker.SetTags(tags)
}

func SetSessionTags(eventId, sessionId int, tags ...string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).SetTags(tags)
}

func AddSpeakerTags(eventId, sessionId int, tags ...string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).Speaker.AddTags(tags)
}

func AddSessionTags(eventId, sessionId int, tags ...string) {
	AssertAdminAccess()
	registry.GetEventSession(eventId, sessionId).AddTags(tags)
}

func SetEventMapContent(markdown string) {
	AssertAdminAccess()
	eventMap.Markdown = markdown
}
