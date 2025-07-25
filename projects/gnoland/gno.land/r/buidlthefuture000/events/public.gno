package events

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/eve000/event"
)

var (
	featuredRealm = ""
	eventRealms   = avl.NewTree()
)

// REVIEW: consider removing this if it is not used for anything else
// SetFeaturedRealm sets the featured realm for the events package.
func SetFeaturedRealm(realm string) {
	assertAccess()
	if realm == "" {
		panic("cannot set empty featured realm")
	}
	featuredRealm = realm
}

// AddEventRealm adds an event realm to the global eventRealms tree.
func AddEventRealm(eveApi event.Api) {
	assertAccess()
	path := std.CurrentRealm().PkgPath()
	if path == "" {
		panic("cannot add event realm with empty path")
	}
	eventRealms.Set(path, eveApi)
}

// Eve returns event.Api for a given realm path.
func Eve(realmPath string) event.Api {
	evt, ok := eventRealms.Get(realmPath)
	if !ok {
		panic("no event realm found for the given path")
	}
	app, ok := evt.(event.Api)
	if !ok {
		panic("event is not an EveApi")
	}
	return app
}

// AddOrganizer adds an organizer to the event realm.
func AddOrganizer(realmPath string, addr std.Address) {
	Eve(realmPath).AddOrganizer(addr)
}

// AddProposer adds a proposer to the event realm.
func AddProposer(realmPath string, addr, sender std.Address) {
	Eve(realmPath).AddProposer(addr, sender)
}

// AddReviewer adds a reviewer to the event realm.
func AddReviewer(realmPath string, addr, sender std.Address) {
	Eve(realmPath).AddReviewer(addr, sender)
}

// AddSpeaker adds a speaker to the event realm.
func AddSpeaker(realmPath string, addr std.Address) {
	Eve(realmPath).AddSpeaker(addr)
}

// AdminAddRole adds a role to the event realm for a given address.
func AdminRemoveRole(realmPath string, role string, addr std.Address) {
	Eve(realmPath).AdminRemoveRole(role, addr)
}

// AdminSetRole sets a role for a given address in the event realm.
func AdminSetRole(realmPath string, role string, addr std.Address) {
	Eve(realmPath).AdminSetRole(role, addr)
}

// FIXME: remove this deprecated func
func AssertAtLeastRole(realmPath string, role string, sender std.Address) {
	Eve(realmPath).AssertAtLeastRole(role, sender)
}

// HasRole checks if the given address has the specified role in the event realm.
func HasRole(realmPath string, role string, addr std.Address) bool {
	return Eve(realmPath).HasRole(role, addr)
}

// JoinAsOrganizer allows the sender to join the event realm as an organizer.
func JoinAsAttendee(realmPath string) {
	Eve(realmPath).JoinAsAttendee()
}

// JoinWaitlist allows the sender to join the event realm's waitlist.
func JoinWaitlist(realmPath string) {
	Eve(realmPath).JoinWaitlist()
}

// ListRoles returns a list of roles in the event realm.
func ListRoles(realmPath string) []string {
	return Eve(realmPath).ListRoles()
}

// RegisterEvent registers an event in the event realm with the given options.
func RegisterEvent(realmPath string, evt *event.Event, opts map[string]interface{}) string {
	return Eve(realmPath).RegisterEvent(evt, opts)
}

// RemoveOrganizer removes an organizer from the event realm.
func RemoveOrganizer(realmPath string, addr std.Address) {
	Eve(realmPath).RemoveOrganizer(addr)
}

// RemoveProposer removes a proposer from the event realm.
func RemoveProposer(realmPath string, addr, sender std.Address) {
	Eve(realmPath).RemoveProposer(addr, sender)
}

// RemoveReviewer removes a reviewer from the event realm.
func RemoveReviewer(realmPath string, addr, sender std.Address) {
	Eve(realmPath).RemoveReviewer(addr, sender)
}

// RemoveSelfAsAttendee removes the sender from the event realm as an attendee.
func RemoveSelfAsAttendee(realmPath string) {
	Eve(realmPath).RemoveSelfAsAttendee()
}

// RemoveSelfFromWaitlist removes the sender from the event realm's waitlist.
func RemoveSelfFromWaitlist(realmPath string) {
	Eve(realmPath).RemoveSelfFromWaitlist()
}

// RemoveSpeaker removes a speaker from the event realm.
func RemoveSpeaker(realmPath string, addr std.Address) {
	Eve(realmPath).RemoveSpeaker(addr)
}

// RenderAcl renders the ACL for the given path in the event realm.
func RenderAcl(realmPath string, path string) string {
	return Eve(realmPath).RenderAcl(path)
}

// RenderList renders the list of events for the given role in the event realm.
func RenderList(realmPath string, role string) string {
	return Eve(realmPath).RenderList(role)
}

// ResetRoles resets all roles in the event realm.
func ResetRoles(realmPath string) {
	Eve(realmPath).ResetRoles()
}

// RoleExists checks if the specified role exists in the event realm.
func RoleExists(realmPath string, role string) bool {
	return Eve(realmPath).RoleExists(role)
}

// SetContent sets the content for a given key in the event realm.
func SetContent(realmPath string, key, markdown string) {
	Eve(realmPath).SetContent(key, markdown)
}

// SetPatchLevel sets the patch level for the event realm.
func SetPatchLevel(realmPath string, level int) {
	Eve(realmPath).SetPatchLevel(level)
}

// SetRoleHandler sets a handler function for a specific role in the event realm.
func SetRoleHandler(realmPath string, role string, fn func(string) bool) {
	Eve(realmPath).SetRoleHandler(role, fn)
}

// UnsetRoleHandler removes the handler function for a specific role in the event realm.
func UnsetRoleHandler(realmPath string, role string) {
	Eve(realmPath).UnsetRoleHandler(role)
}

// Register registers a ContentBlock function - use this to override the default rendering
func Register(key string, block func(string) string) {
	app.Register(key, block)
}

// Render renders the content for the given path using the registered ContentBlock function.
func Render(path string) (out string) {
	return app.Render(path)
}
