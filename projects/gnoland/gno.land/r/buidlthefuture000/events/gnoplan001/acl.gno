package gnoplan

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/txlink"
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

var (
	acl          = &Acl{}
	waitlist     *avl.Tree // use beta
	organizers   *avl.Tree
	speakers     *avl.Tree
	attendees    *avl.Tree
	proposers    *avl.Tree
	reviewers    *avl.Tree
	accessChecks map[string]func(string) bool
	aclOverride  map[string]bool
)

type Acl struct{}

const (
	AssertIsOrganizerMsg            string = "error: The PreviousRealm Address must be in the organizer's group execute this function."
	AssertOrganizerNotRemoveSelfMsg string = "error: an organizer cannot remove itself."
)

func init() {
	aclOverride = make(map[string]bool)
	waitlist = avl.NewTree()

	reviewers = avl.NewTree()
	reviewers.Set("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t", struct{}{})
	reviewers.Set("g1aa5umzchlwqxtdfh58exmydmzsgpzcg3u9egcp", struct{}{})
	reviewers.Set("g140pp6d0wnmpjdrwk2npsz5ay4pwc0374vdvdyt", struct{}{})
	reviewers.Set("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz", struct{}{})

	proposers = avl.NewTree()
	proposers.Set("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t", struct{}{})
	proposers.Set("g1aa5umzchlwqxtdfh58exmydmzsgpzcg3u9egcp", struct{}{})
	proposers.Set("g140pp6d0wnmpjdrwk2npsz5ay4pwc0374vdvdyt", struct{}{})
	proposers.Set("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz", struct{}{})

	organizers = avl.NewTree()
	organizers.Set("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t", struct{}{})
	organizers.Set("g1aa5umzchlwqxtdfh58exmydmzsgpzcg3u9egcp", struct{}{})
	organizers.Set("g140pp6d0wnmpjdrwk2npsz5ay4pwc0374vdvdyt", struct{}{})
	organizers.Set("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz", struct{}{})

	speakers = avl.NewTree()
	speakers.Set("g12m4ecssg9j0pvnhxct3sfky70dy9fk7xrvfwx2", struct{}{})
	speakers.Set("g140pp6d0wnmpjdrwk2npsz5ay4pwc0374vdvdyt", struct{}{})
	speakers.Set("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz", struct{}{})

	attendees = avl.NewTree()
	attendees.Set("g12m4ecssg9j0pvnhxct3sfky70dy9fk7xrvfwx2", struct{}{})
	attendees.Set("g1yfts8fy9jyfeca4p42em6mcttfwcypkpkfx0rv", struct{}{})
	attendees.Set("g140pp6d0wnmpjdrwk2npsz5ay4pwc0374vdvdyt", struct{}{})
	attendees.Set("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz", struct{}{})

	accessChecks = map[string]func(string) bool{
		"waitlist":  waitlist.Has,
		"proposer":  proposers.Has,
		"reviewer":  reviewers.Has,
		"attendee":  attendees.Has,
		"speaker":   speakers.Has,
		"organizer": organizers.Has,
	}
}

// Use Admin access to set the role of an address.
func (*Acl) AdminSetRole(role string, addr std.Address) {
	assertAccess()
	switch role {
	case "waitlist":
		waitlist.Set(string(addr), struct{}{})
	case "attendee":
		attendees.Set(string(addr), struct{}{})
	case "speaker":
		speakers.Set(string(addr), struct{}{})
	case "organizer":
		organizers.Set(string(addr), struct{}{})
	case "proposer":
		proposers.Set(string(addr), struct{}{})
	case "reviewer":
		reviewers.Set(string(addr), struct{}{})
	default:
		panic(ufmt.Sprintf("error: role %s not supported", role))
	}
}

// AdminRemoveRole removes the address from the specified role.
func (*Acl) AdminRemoveRole(role string, addr std.Address) {
	assertAccess()
	switch role {
	case "waitlist":
		waitlist.Remove(string(addr))
	case "attendee":
		attendees.Remove(string(addr))
	case "speaker":
		speakers.Remove(string(addr))
	case "organizer":
		organizers.Remove(string(addr))
	case "proposer":
		proposers.Remove(string(addr))
	case "reviewer":
		reviewers.Remove(string(addr))
	default:
		panic(ufmt.Sprintf("error: role %s not supported", role))
	}
}

// ResetRoles resets all roles to empty trees and re-initializes the accessChecks map.
func (*Acl) ResetRoles() {
	assertAccess()
	waitlist = avl.NewTree()
	organizers = avl.NewTree()
	speakers = avl.NewTree()
	attendees = avl.NewTree()
	proposers = avl.NewTree()
	reviewers = avl.NewTree()
	accessChecks = map[string]func(string) bool{
		"beta":  waitlist.Has, // extra beta role
		"waitlist":  waitlist.Has,
		"proposer":  proposers.Has,
		"reviewer":  reviewers.Has,
		"attendee":  attendees.Has,
		"speaker":   speakers.Has,
		"organizer": organizers.Has,
	}
}

// JoinWaitlist sets the address of the previous realm as an waitlist attendee
// for the event.
func (*Acl) JoinWaitlist() {
	waitlist.Set(string(std.PreviousRealm().Address()), struct{}{})
}

// Extra func for beta
func (*Acl) JoinBeta() {
	waitlist.Set(string(std.PreviousRealm().Address()), struct{}{})
}

// RemoveSelfFromWaitlist removes the address of the previous realm as a waitlist attendee
// for the event.
func (*Acl) RemoveSelfFromWaitlist() {
	waitlist.Remove(string(std.PreviousRealm().Address()))
}

// JoinAsAttendee sets the address of the previous realm as an attendee
// for the event.
func (*Acl) JoinAsAttendee() {
	attendees.Set(string(std.PreviousRealm().Address()), struct{}{})
}

// RemoveSelfAsAttendee removes the address of the previous realm as an attendee
// for the event.
func (*Acl) RemoveSelfAsAttendee() {
	attendees.Remove(string(std.PreviousRealm().Address()))
}

// AddSpeaker takes a std.Address and adds it to the speaker tree if the caller is an organizer.
func (*Acl) AddSpeaker(addr std.Address) {
	assertIsOrganizer()
	speakers.Set(string(addr), struct{}{})
}

// RemoveSpeaker takes an std.Address and removes it from the speaker tree if the call is an organizer.
func (*Acl) RemoveSpeaker(addr std.Address) {
	assertIsOrganizer()
	speakers.Remove(string(addr))
}

// AddOrganizer takes a std.Address and adds it to the speaker tree if the caller is an organizer.
func (*Acl) AddOrganizer(addr std.Address) {
	assertIsOrganizer()
	organizers.Set(string(addr), struct{}{})
}

// RemoveOrganizer takes an std.Address and removes it from the speaker tree if the call is an organizer and
// the caller isn't trying to remove itself.
func (*Acl) RemoveOrganizer(addr std.Address) {
	assertIsOrganizer()
	if addr == std.PreviousRealm().Address() {
		panic(AssertOrganizerNotRemoveSelfMsg)
	}
	organizers.Remove(string(addr))
}

// assertIsOrganizer panics if the PreviousRealm address is not in the organizers tree.
func assertIsOrganizer() {
	if !organizers.Has(string(std.PreviousRealm().Address())) {
		panic(AssertIsOrganizerMsg)
	}
}

// Public API for organizers to manage proposers and reviewers
func (*Acl) AddProposer(addr, sender std.Address) {
	acl.AssertAtLeastRole("organizer", sender)
	proposers.Set(string(addr), struct{}{})
}

func (*Acl) RemoveProposer(addr, sender std.Address) {
	acl.AssertAtLeastRole("organizer", sender)
	proposers.Remove(string(addr))
}

func (*Acl) AddReviewer(addr, sender std.Address) {
	acl.AssertAtLeastRole("organizer", sender)
	reviewers.Set(string(addr), struct{}{})
}

func (*Acl) RemoveReviewer(addr, sender std.Address) {
	acl.AssertAtLeastRole("organizer", sender)
	reviewers.Remove(string(addr))
}

// RoleExists takes a role and returns a boolean value that indicates whether or not
// that role exists in the accessChecks map. It returns false if any other role type is requested.
func (*Acl) RoleExists(role string) bool {
	if _, ok := accessChecks[role]; ok {
		return true
	}
	return false
}

// HasRole takes a role and an address and returns a boolean value that indicates whether or not
func (*Acl) HasRole(role string, addr std.Address) bool {
	if fn, ok := accessChecks[role]; ok {
		return fn(string(addr))
	}
	return false
}

// ListRoles returns a slice of strings that contains all the roles in the accessChecks map.
func (*Acl) ListRoles() []string {
	roles := make([]string, 0)
	for role := range accessChecks {
		roles = append(roles, role)
	}
	return roles
}

// SetRoleHandler takes a role and a function that takes an address and returns a boolean value.
func (*Acl) SetRoleHandler(role string, fn func(string) bool) {
	aclOverride[role] = true
	assertAccess()
	accessChecks[role] = fn
}

// UnsetRoleHandler takes a role and removes it from the accessChecks map.
func (*Acl) UnsetRoleHandler(role string) {
	assertAccess()
	delete(accessChecks, role)
}

func (*Acl) AssertAtLeastRole(role string, sender std.Address) {
	if !acl.HasRole(role, sender) {
		panic(ufmt.Sprintf("address %s must have %s role or higher", sender, role))
	}
}

// Render takes no arguments and displays a simple page showing up to 100
func (*Acl) Render(path string) string {
	id := registry.LiveEventId
	evt := registry.GetEvent(id)
	if evt.Name == "" {
		panic(ufmt.Sprintf("error: event with id %d not found", id))
	}
	var sb strings.Builder
	sb.WriteString(ufmt.Sprintf(`# `+evt.Name+`

## Event access control

This realm can check membership by Querying [HasRole(role, addr)](./gnolandlaunch$help#func-HasRole), where
a role can be proposer, reviewer, attendee, speaker, or organizer.

Note: This renderer will only display up to 100 addresses per group.

### Easy Actions

- [Join Waitlist](%v)
- [Remove yourself from Waitlist](%v)

- [Join as an Attendee](%v)
- [Remove yourself as an Attendee](%v)
`,
		txlink.NewLink("JoinWaitlist").URL(),
		txlink.NewLink("RemoveSelfFromWaitlist").URL(),
		txlink.NewLink("JoinAsAttendee").URL(),
		txlink.NewLink("RemoveSelfAsAttendee").URL()))

	sb.WriteString("## Roles")
	for role, _ := range accessChecks {
		list := acl.RenderList(role)
		if list != "" {
			sb.WriteString(ufmt.Sprintf("\n%s\n", acl.RenderList(role)))
		}
	}

	return sb.String()
}

func (*Acl) RenderList(role string) string {
	var sb strings.Builder
	sb.WriteString(ufmt.Sprintf("\n### %s \n", role))
	var addrs []std.Address
	if aclOverride[role] {
		sb.WriteString(ufmt.Sprintf("This role has a custom ACL handler.\n"))
		return sb.String()
	}
	switch role {
	case "waitlist":
		addrs = treeToSlice(waitlist)
	case "attendee":
		addrs = treeToSlice(attendees)
	case "speaker":
		addrs = treeToSlice(speakers)
	case "organizer":
		addrs = treeToSlice(organizers)
	case "proposer":
		addrs = treeToSlice(proposers)
	case "reviewer":
		addrs = treeToSlice(reviewers)
	default:
		return ""
	}
	if len(addrs) == 0 {
		return ""
	}
	sb.WriteString(toMDList(addrs))
	return sb.String()
}

// treeToSlice takes an AVL tree and returns up to 100 items in order of index.
func treeToSlice(tree *avl.Tree) []std.Address {
	result := make([]std.Address, 0)
	tree.IterateByOffset(0, 100, func(k string, _ any) bool {
		if k == "" {
			return true
		}
		result = append(result, std.Address(k))
		return false
	})
	return result
}

// toMDList takes a slice of addresses and returns a Markdown encoded list as a string.
func toMDList(addrs []std.Address) string {
	var result string
	for _, addr := range addrs {
		result += ufmt.Sprintf("- %v\n", string(addr))
	}
	return result
}
