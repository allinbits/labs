package gnolandlaunch

import (
	"net/url"
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/register"
)

var (
	staticContent = &component.Content{
		Published: false,
		Markdown:  "This page has been disabled",
	}
	eventMap = &component.Content{
		Published: false,
		Markdown:  "This page has been disabled",
	}

	realmAllowPrefix = []string{} // realms prefixes that have access to update the registry
	registry         = &register.Registry{}
)

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/patch")

	registry.SetRenderOpts(renderOpts)
	id := registry.RegisterEvent(gnolandlaunch, renderOpts)
	registry.LiveEventId = id
}

func NotEmpty(value string) bool {
	return value != ""
}

func Render(path string) (out string) {
    return render(path) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}

func render(path string) (out string) {
	fullURL := std.CurrentRealm().PkgPath() + path
	u, err := url.Parse(fullURL)
	if err != nil {
		panic("Error Parsing URL")
	}
	q := u.Query()
	event_id := q.Get("event")
	if event_id == "" {
		event_id = registry.LiveEventId
	}

	event := registry.GetEvent(event_id)
	switch {
	case NotEmpty(q.Get("session")):
		return component.RenderComponent(path, event.GetSession(q.Get("session")))
	case NotEmpty(q.Get("location")):
		return component.RenderComponent(path, event.GetLocation(q.Get("location")))
	case NotEmpty(q.Get("speaker")):
		return component.RenderComponent(path, event.GetSpeaker(q.Get("speaker")))
	default:
		agenda := event.Agenda()
		agenda.SetBanner(banner)
		return component.RenderComponent(path, agenda)
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
	return ufmt.Sprintf("%s\n\nliveEvent: %d\n\npath: %v", msg, registry.LiveEventId, path)
}

/* Content Management API */
/*
func Publish(markdown string) {
	AssertAdminAccess()
	staticContent.Published = true
	staticContent.Markdown = markdown
}

func Destroy(markdown string) {
	Publish(markdown)
	registry = register.NewRegistry(renderOpts) // reset the registry to a new instance
}

/*
func Revision() string {
	patchLevelStr := strconv.Itoa(eventRegistry.PatchLevel)
	if eventRegistry.PatchLevel < 10 {
		patchLevelStr = "00" + patchLevelStr
	} else if eventRegistry.PatchLevel < 100 {
		patchLevelStr = "0" + patchLevelStr
	}
	return "\n\n[rev: " + strconv.Itoa(eventRegistry.PatchLevel) + "](./gophercon/patch" + patchLevelStr + ")\n\n"
}
*/

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
	registry.SetPatchLevel(level)
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
