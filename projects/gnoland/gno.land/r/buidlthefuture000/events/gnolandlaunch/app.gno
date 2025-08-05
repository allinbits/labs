package gnolandlaunch

import (
	"std"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

type App struct{}

var (
	_ event.Api = (*App)(nil)

	app = &App{}

	realmAllowPrefix = []string{} // realms prefixes that have access to update the registry
	registry         = &event.Registry{}
)

func (*App) Render(path string) (out string) {
	return registry.Render(path, banner) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}

func (*App) RenderCalendar(path string) string {
	return app.LiveEvent().Render(path, eve.IcsCalendarFile)
}

func (*App) SetContent(key, markdown string) {
	assertAccess()
	switch key {
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

func (*App) PublishEvent(evt *event.Event, opts map[string]interface{}) string {
	id := app.RegisterEvent(evt, opts)
	registry.LiveEventId = id
	return id
}

func (*App) RegisterEvent(evt *event.Event, opts map[string]interface{}) string {
	registry.SetRenderOpts(opts)
	return registry.RegisterEvent(evt, opts)
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
