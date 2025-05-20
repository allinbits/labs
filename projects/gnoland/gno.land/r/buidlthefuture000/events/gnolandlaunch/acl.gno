package event

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/txlink"
)

var (
	organizers *avl.Tree
	speakers   *avl.Tree
	attendees  *avl.Tree
	proposers  *avl.Tree
	reviewers  *avl.Tree
)

const (
	AssertIsOrganizerMsg            string = "error: The PreviousRealm Address must be in the organizer's group execute this function."
	AssertOrganizerNotRemoveSelfMsg string = "error: an organizer cannot remove itself."
)

func init() {
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
}

// JoinAsAttendee sets the address of the previous realm as an attendee
// for the event.
func JoinAsAttendee() {
	crossing()
	attendees.Set(string(std.PreviousRealm().Address()), struct{}{})
}

// RemoveSelfAsAttendee removes the address of the previous realm as an attendee
// for the event.
func RemoveSelfAsAttendee() {
	crossing()
	attendees.Remove(string(std.PreviousRealm().Address()))
}

// AddSpeaker takes a std.Address and adds it to the speaker tree if the caller is an organizer.
func AddSpeaker(addr std.Address) {
	crossing()
	assertIsOrganizer()
	speakers.Set(string(addr), struct{}{})
}

// RemoveSpeaker takes an std.Address and removes it from the speaker tree if the call is an organizer.
func RemoveSpeaker(addr std.Address) {
	crossing()
	assertIsOrganizer()
	speakers.Remove(string(addr))
}

// AddOrganizer takes a std.Address and adds it to the speaker tree if the caller is an organizer.
func AddOrganizer(addr std.Address) {
	crossing()
	assertIsOrganizer()
	organizers.Set(string(addr), struct{}{})
}

// RemoveOrganizer takes an std.Address and removes it from the speaker tree if the call is an organizer and
// the caller isn't trying to remove itself.
func RemoveOrganizer(addr std.Address) {
	crossing()
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
func AddProposer(addr, sender std.Address) {
	AssertAtLeastRole("organizer", sender)
	proposers.Set(string(addr), struct{}{})
}

func RemoveProposer(addr, sender std.Address) {
	AssertAtLeastRole("organizer", sender)
	proposers.Remove(string(addr))
}

func AddReviewer(addr, sender std.Address) {
	AssertAtLeastRole("organizer", sender)
	reviewers.Set(string(addr), struct{}{})
}

func RemoveReviewer(addr, sender std.Address) {
	AssertAtLeastRole("organizer", sender)
	reviewers.Remove(string(addr))
}

// HasRole takes a role and an address and returns a boolean value that indicates whether or not
// that address is a member of one of three supported roles, `attendee`, `speaker`, and `organizer`.
// It returns false if any other role type is requested.
func HasRole(role string, addr std.Address) bool {
	crossing()
	switch role {
	case "proposer":
		return proposers.Has(string(addr))
	case "reviewer":
		return reviewers.Has(string(addr))
	case "attendee":
		return attendees.Has(string(addr))
	case "speaker":
		return speakers.Has(string(addr))
	case "organizer":
		return organizers.Has(string(addr))
	default:
		return false
	}
}

func AssertAtLeastRole(role string, sender std.Address) {
	crossing()
	if !HasRole(role, sender) {
		panic(ufmt.Sprintf("address %s must have %s role or higher", sender, role))
	}
}

// Render takes no arguments and displays a simple page showing up to 100
// addresses per role group.
func RenderAcl(path string) string {
	id := getIdFromPath(path)
	evt := registry.GetEvent(id)
	if evt.Name == "" {
		panic(ufmt.Sprintf("error: event with id %d not found", id))
	}

	return ufmt.Sprintf(`# `+evt.Name+`

Event organizer and attendee list.

This realm can check membership by Querying [HasRole(role, addr)](gnolandlaunch:access-control$help#func-HasRole), where
a role can be attendee, speaker, or organizer.

Note: This renderer will only display up to 100 addresses per group.

## Easy Actions:

- [Join as an Attendee](%v)
- [Remove yourself as an Attendee](%v)


## Organizers

%v

## Speakers

%v

## Attendees

%v

`,
		txlink.NewLink("JoinAsAttendee").URL(),
		txlink.NewLink("RemoveSelfAsAttendee").URL(),
		toMDList(treeToSlice(organizers)),
		toMDList(treeToSlice(speakers)),
		toMDList(treeToSlice(attendees)))
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
