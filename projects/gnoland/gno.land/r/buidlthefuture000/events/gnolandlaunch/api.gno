package gnolandlaunch

import (
	"net/url"
	"std"

	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/register"
)

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
func (*Api) AdminSetRole(role string, addr std.Address) {
	acl.AdminSetRole(role, addr)
}

func (*Api) AdminRemoveRole(role string, addr std.Address) {
	acl.AdminRemoveRole(role, addr)
}
func (*Api) ResetRoles() {
	acl.ResetRoles()
}
func (*Api) JoinWaitlist() {
	acl.JoinWaitlist()
}
func (*Api) RemoveSelfFromWaitlist() {
	acl.RemoveSelfFromWaitlist()
}
func (*Api) JoinAsAttendee() {
	acl.JoinAsAttendee()
}
func (*Api) RemoveSelfAsAttendee() {
	acl.RemoveSelfAsAttendee()
}
func (*Api) AddSpeaker(addr std.Address) {
	acl.AddSpeaker(addr)
}
func (*Api) RemoveSpeaker(addr std.Address) {
	acl.RemoveSpeaker(addr)
}
func (*Api) AddOrganizer(addr std.Address) {
	acl.AddOrganizer(addr)
}
func (*Api) RemoveOrganizer(addr std.Address) {
	acl.RemoveOrganizer(addr)
}
func (*Api) AddProposer(addr, sender std.Address) {
	acl.AddProposer(addr, sender)
}
func (*Api) RemoveProposer(addr, sender std.Address) {
	acl.RemoveProposer(addr, sender)
}
func (*Api) AddReviewer(addr, sender std.Address) {
	acl.AddReviewer(addr, sender)
}
func (*Api) RemoveReviewer(addr, sender std.Address) {
	acl.RemoveReviewer(addr, sender)
}
func (*Api) RoleExists(role string) bool {
	return acl.RoleExists(role)
}
func (*Api) HasRole(role string, addr std.Address) bool {
	return acl.HasRole(role, addr)
}
func (*Api) ListRoles() []string {
	return acl.ListRoles()
}
func (*Api) SetRoleHandler(role string, fn func(string) bool) {
	acl.SetRoleHandler(role, fn)
}
func (*Api) UnsetRoleHandler(role string) {
	acl.UnsetRoleHandler(role)
}
func (*Api) AssertAtLeastRole(role string, sender std.Address) {
	acl.AssertAtLeastRole(role, sender)
}
func (*Api) RenderList(role string) string {
	return acl.RenderList(role)
}

func (*Api) RenderAcl(path string) string {
	return acl.Render(path)
}
