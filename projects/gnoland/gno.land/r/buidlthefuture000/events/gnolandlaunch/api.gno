package gnolandlaunch

import (
	"net/url"
	"std"
	"strings"

	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/register"
)

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/patch")
}

func hasAllowedPrefix() bool {
	currentRealm := std.CurrentRealm()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(currentRealm.PkgPath(), callerPath) {
			return true
		}
	}
	return false
}

// assertAccess is used to restrict access to certain functions intended to be used by patch-realm admins.
func assertAccess() {
	if !hasAllowedPrefix() {
		panic("access denied: " + std.CurrentRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}

type Api struct{}

var (
	api = &Api{}

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

func notEmpty(value string) bool {
	return value != ""
}

func Render(path string) (out string) {
	return api.Render(path) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}

func (*Api) Render(path string) (out string) {
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
	case notEmpty(q.Get("session")):
		return component.RenderComponent(path, event.GetSession(q.Get("session")))
	case notEmpty(q.Get("location")):
		return component.RenderComponent(path, event.GetLocation(q.Get("location")))
	case notEmpty(q.Get("speaker")):
		return component.RenderComponent(path, event.GetSpeaker(q.Get("speaker")))
	default:
		agenda := event.Agenda()
		agenda.SetBanner(banner) // REVIEW: is there a better way to inject the banner?
		return component.RenderComponent(path, agenda)
	}
}

func (*Api) Publish(markdown string) {
	assertAccess()
	staticContent.Published = true
	staticContent.Markdown = markdown
}

func (*Api) Destroy(markdown string) {
	api.Publish(markdown)
	registry = register.NewRegistry(registry.RenderOpts) // reset the registry to a new instance
}

func (*Api) Unpublish(key string) {
	assertAccess()
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

func (*Api) SetContent(key, markdown string) {
	assertAccess()
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

func (*Api) SetPatchLevel(level int) {
	assertAccess()
	registry.SetPatchLevel(level)
}

func (*Api) RegisterEvent(evt *event.Event, opts *component.RenderOpts) string {
	registry.SetRenderOpts(opts) // REVIEW: still needed?
	id := registry.RegisterEvent(evt, opts)
	registry.LiveEventId = id
	return id
}
