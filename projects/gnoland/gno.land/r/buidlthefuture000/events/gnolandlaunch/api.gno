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
	"gno.land/p/moul/txlink"
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
	banner = &component.Content{
		Published: true,
		Markdown: "\n\n#### Status: Accepting Session Proposals\n\n" +
			"Join us on [discord](https://discord.gg/YFtMjWwUN7) to get access to submit a proposal.\n\n" +
			"or\n\n" + txlinkButton("Register To Attend", "JoinWaitlist"),
	}
	renderOpts = &component.RenderOpts{
		Location: false,
		Svg:      true,
		Schedule: true,
		Speaker:  false,
	}
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
		LiveEventId: registry.RegisterEvent(gnoLandLaunchEvent),
		PatchLevel:  0,
	}
}

func Render(path string) (out string) {
	if staticContent.Published && path == "" {
		return staticContent.Markdown
	}
	id := getIdFromPath(path)
	switch {
	case strings.HasPrefix(path, "access-control"):
		return RenderAcl(path)
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
	// case strings.HasPrefix(path, "?tag="):
	//	tag := strings.TrimPrefix(path, "?tag=")
	//	return AgendaMarkdown(id, tag)
	case strings.HasPrefix(path, "event:") || path == "" || path == "json":
		evt := registry.GetEvent(id)
		if evt.Name == "" {
			panic(ufmt.Sprintf("error: event with id %d not found", id))
		} else {
			agenda := evt.Agenda()
			agenda.SetBanner(banner) // inject banner
			return component.RenderComponent(path, agenda)
		}
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
	case "banner":
		banner.Published = false
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
	case "banner":
		banner.SetPublished(true)
		banner.SetMarkdown(markdown)
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

// AssertAdminAccess panics if the caller's realm does not match the allowed prefix.
// This is used to restrict access to certain functions intended to be used by patch-realm admins.
func AssertAdminAccess() {
	if !HasAllowedPrefix() {
		panic("access denied: " + std.CurrentRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}

/* Speaker API */
func AddSpeakerRecord() int {
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

func txlinkButton(label, method string) string {
	return component.Button(label, txlink.NewLink(method).URL())
}
