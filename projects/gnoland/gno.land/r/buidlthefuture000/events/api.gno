package events

import (
	"std"

	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/component"
)

var api EveApi

func SetApp(app EveApi) {
	if app == nil {
		// emit app is disabled
	} else {
		// emit updated app
	}
	api = app
}

func eve() EveApi {
	if api == nil {
		panic("app is disabled")
	}
	return api
}

type EveApi interface {
	AddOrganizer(addr std.Address)
	AddProposer(addr, sender std.Address)
	AddReviewer(addr, sender std.Address)
	AddSpeaker(addr std.Address)
	AdminRemoveRole(role string, addr std.Address)
	AdminSetRole(role string, addr std.Address)
	AssertAtLeastRole(role string, sender std.Address)
	Destroy(markdown string)
	HasRole(role string, addr std.Address) bool
	JoinAsAttendee()
	JoinWaitlist()
	ListRoles() []string
	Publish(markdown string)
	RegisterEvent(evt *event.Event, opts *component.RenderOpts) string
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
	Unpublish(key string)
	UnsetRoleHandler(role string)
}

func AddOrganizer(addr std.Address) {
	eve().AddOrganizer(addr)
}
func AddProposer(addr, sender std.Address) {
	eve().AddProposer(addr, sender)
}
func AddReviewer(addr, sender std.Address) {
	eve().AddReviewer(addr, sender)
}
func AddSpeaker(addr std.Address) {
	eve().AddSpeaker(addr)
}
func AdminRemoveRole(role string, addr std.Address) {
	eve().AdminRemoveRole(role, addr)
}
func AdminSetRole(role string, addr std.Address) {
	eve().AdminSetRole(role, addr)
}

// TODO: deprecate
func AssertAtLeastRole(role string, sender std.Address) {
	eve().AssertAtLeastRole(role, sender)
}
func Destroy(markdown string) {
	eve().Destroy(markdown)
}
func HasRole(role string, addr std.Address) bool {
	return eve().HasRole(role, addr)
}
func JoinAsAttendee() {
	eve().JoinAsAttendee()
}
func JoinWaitlist() {
	eve().JoinWaitlist()
}
func ListRoles() []string {
	return eve().ListRoles()
}
func Publish(markdown string) {
	eve().Publish(markdown)
}
func RegisterEvent(evt *event.Event, opts *component.RenderOpts) string {
	return ""
}
func RemoveOrganizer(addr std.Address) {
	eve().RemoveOrganizer(addr)
}
func RemoveProposer(addr, sender std.Address) {
	eve().RemoveProposer(addr, sender)
}
func RemoveReviewer(addr, sender std.Address) {
	eve().RemoveReviewer(addr, sender)
}
func RemoveSelfAsAttendee() {
	eve().RemoveSelfAsAttendee()
}
func RemoveSelfFromWaitlist() {
	eve().RemoveSelfFromWaitlist()
}
func RemoveSpeaker(addr std.Address) {
	eve().RemoveSpeaker(addr)
}

//	func Render(path string) (out string) {
//	    return ""
//	}
func RenderAcl(path string) string {
	return eve().RenderAcl(path)
}
func RenderList(role string) string {
	return eve().RenderList(role)
}
func ResetRoles() {
	eve().ResetRoles()
}
func RoleExists(role string) bool {
	return eve().RoleExists(role)
}
func SetContent(key, markdown string) {
	eve().SetContent(key, markdown)
}
func SetPatchLevel(level int) {
	eve().SetPatchLevel(level)
}
func SetRoleHandler(role string, fn func(string) bool) {
	eve().SetRoleHandler(role, fn)
}
func Unpublish(key string) {
	eve().Unpublish(key)
}
func UnsetRoleHandler(role string) {
	eve().UnsetRoleHandler(role)
}
