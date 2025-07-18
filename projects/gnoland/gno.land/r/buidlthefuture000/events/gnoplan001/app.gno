package gnoplan

import (
	"net/url"
	"std"

	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/register"
	"gno.land/p/eve000/event/session"
)

type App struct{}

var (
	_ event.Api = (*App)(nil)

	app = &App{}

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
	return app.Render(path) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}

func getQueryParam(q url.Values, param string) (string, bool) {
	if q == nil {
		return "", false
	}
	value := q.Get(param)
	if value == "" {
		return "", false
	}
	return value, true
}

func hasQueryParam(q url.Values, param string) bool {
	_, ok := getQueryParam(q, param)
	return ok
}

func (*App) Render(path string) (out string) {
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
	case hasQueryParam(q, "session"):
		return component.RenderComponent(path, event.GetSession(q.Get("session")))
	case hasQueryParam(q, "location"):
		return component.RenderComponent(path, event.GetLocation(q.Get("location")))
	case hasQueryParam(q, "speaker"):
		return component.RenderComponent(path, event.GetSpeaker(q.Get("speaker")))
	default:
		return component.RenderComponent(path, event.Agenda(banner))
	}
}

func (*App) Publish(markdown string) {
	assertAccess()
	staticContent.Published = true
	staticContent.Markdown = markdown
}

func (*App) Destroy(markdown string) {
	app.Publish(markdown)
	registry = register.NewRegistry(registry.RenderOpts) // reset the registry to a new instance
}

func (*App) Unpublish(key string) {
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

func (*App) SetContent(key, markdown string) {
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

func (*App) SetPatchLevel(level int) {
	assertAccess()
	registry.SetPatchLevel(level)
}

func (*App) LiveEvent() *event.Event {
	// assertAccess() // REVIEW: should this be protected?
	return registry.GetEvent(registry.LiveEventId)
}

func (*App) RegisterEvent(evt *event.Event, opts map[string]interface{}) string {
	registry.SetRenderOpts(opts)
	id := registry.RegisterEvent(evt, opts)
	registry.LiveEventId = id
	return id
}

func (*App) AdminSetRole(role string, addr std.Address) {
	acl.AdminSetRole(role, addr)
}

func (*App) AdminRemoveRole(role string, addr std.Address) {
	acl.AdminRemoveRole(role, addr)
}
func (*App) ResetRoles() {
	acl.ResetRoles()
}
func (*App) JoinWaitlist() {
	acl.JoinWaitlist()
}
func (*App) RemoveSelfFromWaitlist() {
	acl.RemoveSelfFromWaitlist()
}
func (*App) JoinAsAttendee() {
	acl.JoinAsAttendee()
}
func (*App) RemoveSelfAsAttendee() {
	acl.RemoveSelfAsAttendee()
}
func (*App) AddSpeaker(addr std.Address) {
	acl.AddSpeaker(addr)
}
func (*App) RemoveSpeaker(addr std.Address) {
	acl.RemoveSpeaker(addr)
}
func (*App) AddOrganizer(addr std.Address) {
	acl.AddOrganizer(addr)
}
func (*App) RemoveOrganizer(addr std.Address) {
	acl.RemoveOrganizer(addr)
}
func (*App) AddProposer(addr, sender std.Address) {
	acl.AddProposer(addr, sender)
}
func (*App) RemoveProposer(addr, sender std.Address) {
	acl.RemoveProposer(addr, sender)
}
func (*App) AddReviewer(addr, sender std.Address) {
	acl.AddReviewer(addr, sender)
}
func (*App) RemoveReviewer(addr, sender std.Address) {
	acl.RemoveReviewer(addr, sender)
}
func (*App) RoleExists(role string) bool {
	return acl.RoleExists(role)
}
func (*App) HasRole(role string, addr std.Address) bool {
	return acl.HasRole(role, addr)
}
func (*App) ListRoles() []string {
	return acl.ListRoles()
}
func (*App) SetRoleHandler(role string, fn func(string) bool) {
	acl.SetRoleHandler(role, fn)
}
func (*App) UnsetRoleHandler(role string) {
	acl.UnsetRoleHandler(role)
}
func (*App) AssertAtLeastRole(role string, sender std.Address) {
	acl.AssertAtLeastRole(role, sender)
}
func (*App) RenderList(role string) string {
	return acl.RenderList(role)
}

func (*App) RenderAcl(path string) string {
	return acl.Render(path)
}

// REVIEW: should this be added to event.Api interface?
func (*App) GetSession(id int) *session.Session {
	// FIXME
	return registry.GetEvent(registry.LiveEventId).GetSession(string(id))
}
