package mockevent

// import (
// 	"std"
// 	"testing"

// 	"gno.land/p/demo/avl"
// 	"gno.land/p/demo/testutils"
// 	"gno.land/p/demo/ufmt"
// )

// func TestJoinAsAttendee(t *testing.T) {
// 	alice := testutils.TestAddress("alice")
// 	testing.SetOriginCaller(alice)
// 	if HasRole("attendee", alice) != false {
// 		t.Error("alice should not be in attendees yet")
// 	}

// 	JoinAsAttendee()
// 	if HasRole("attendee", alice) != true {
// 		t.Error("alice not found in attendee role")
// 	}
// }

// func TestRemoveSelfAsAttendee(t *testing.T) {
// 	alice := testutils.TestAddress("alice")
// 	testing.SetOriginCaller(alice)
// 	JoinAsAttendee()
// 	RemoveSelfAsAttendee()
// 	if HasRole("attendee", alice) != false {
// 		t.Error("alice should not be in attendees yet")
// 	}
// }

// func TestAddSpeaker(t *testing.T) {
// 	knownOrganizer := std.Address("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")
// 	alice := testutils.TestAddress("alice")
// 	bob := testutils.TestAddress("bob")

// 	testing.SetOriginCaller(knownOrganizer)
// 	AddSpeaker(alice)

// 	if HasRole("speaker", alice) != true {
// 		t.Error("alice not found in speaker role")
// 	}

// 	testing.SetOriginCaller(bob)
// 	r := revive(func() {
// 		AddSpeaker(alice)
// 	})

// 	if r != AssertIsOrganizerMsg {
// 		t.Error("expected panic on non-organizer adding speaker")
// 	}
// }

// func TestRemoveSpeaker(t *testing.T) {
// 	knownOrganizer := std.Address("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")
// 	alice := testutils.TestAddress("alice")
// 	bob := testutils.TestAddress("bob")

// 	testing.SetOriginCaller(knownOrganizer)
// 	AddSpeaker(alice)

// 	testing.SetOriginCaller(bob)
// 	r := revive(func() {
// 		RemoveSpeaker(alice)
// 	})
// 	if r != AssertIsOrganizerMsg {
// 		t.Error("expected panic on non-organizer adding speaker")
// 	}
// 	testing.SetOriginCaller(knownOrganizer)
// 	RemoveSpeaker(alice)
// 	if HasRole("speaker", alice) != false {
// 		t.Error("alice should no longer be a speaker")
// 	}
// }

// func TestAddOrganizer(t *testing.T) {
// 	knownOrganizer := std.Address("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")
// 	alice := testutils.TestAddress("alice")
// 	bob := testutils.TestAddress("bob")

// 	if HasRole("organizer", alice) != false {
// 		t.Error("alice should not already be an organizer")
// 	}
// 	testing.SetOriginCaller(bob)
// 	r := revive(func() {
// 		AddOrganizer(alice)
// 	})
// 	if r != AssertIsOrganizerMsg {
// 		t.Error("expected panic on non-organizer adding speaker")
// 	}
// 	testing.SetOriginCaller(knownOrganizer)
// 	AddOrganizer(alice)

// 	if HasRole("organizer", alice) != true {
// 		t.Error("alice should be an organizer")
// 	}
// }

// func TestRemoveOrganizer(t *testing.T) {
// 	knownOrganizer := std.Address("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")
// 	alice := testutils.TestAddress("alice")
// 	bob := testutils.TestAddress("bob")

// 	testing.SetOriginCaller(knownOrganizer)
// 	AddOrganizer(alice)

// 	testing.SetOriginCaller(bob)
// 	r := revive(func() {
// 		RemoveOrganizer(alice)
// 	})
// 	if r != AssertIsOrganizerMsg {
// 		t.Error("expected panic on non-organizer adding speaker")
// 	}

// 	testing.SetOriginCaller(knownOrganizer)
// 	RemoveOrganizer(alice)

// 	if HasRole("organizer", alice) != false {
// 		t.Error("alice should be removed as organizer")
// 	}
// 	testing.SetOriginCaller(knownOrganizer)
// 	r = revive(func() {
// 		RemoveOrganizer(knownOrganizer)
// 	})
// 	if r != AssertOrganizerNotRemoveSelfMsg {
// 		t.Error("expected panic on organizer attempting to remove self")
// 	}
// }

// func TestTreeToSlice(t *testing.T) {
// 	genAddrs := func(count int) []std.Address {
// 		results := []std.Address{}
// 		for i := 0; i < count; i++ {
// 			results = append(results, testutils.TestAddress(ufmt.Sprintf("%v", i)))
// 		}
// 		return results
// 	}
// 	{
// 		addrs := genAddrs(20)
// 		tree := avl.NewTree()
// 		for _, addr := range addrs {
// 			tree.Set(string(addr), struct{}{})
// 		}

// 		treeAddrs := treeToSlice(tree)

// 		if len(treeAddrs) != 20 {
// 			t.Error("length mismatch, expected 20 results")
// 		}

// 		for _, addr := range treeAddrs {
// 			if !tree.Has(string(addr)) {
// 				t.Error("tree is missing addr: " + string(addr))
// 			}
// 		}
// 	}
// 	{
// 		addrs := genAddrs(120)
// 		tree := avl.NewTree()
// 		for _, addr := range addrs {
// 			tree.Set(string(addr), struct{}{})
// 		}
// 		treeAddrs := treeToSlice(tree)
// 		if len(treeAddrs) != 100 {
// 			t.Error("length mismatch, expected max result of 100 addrs")
// 		}
// 		for _, addr := range treeAddrs {
// 			if !tree.Has(string(addr)) {
// 				t.Error("tree is missing addr: " + string(addr))
// 			}
// 		}
// 	}
// }

// func TestToMDList(t *testing.T) {
// 	addrs := []std.Address{
// 		testutils.TestAddress("u1"),
// 		testutils.TestAddress("u2"),
// 		testutils.TestAddress("u3"),
// 		testutils.TestAddress("u4"),
// 	}
// 	got := toMDList(addrs)
// 	expected := `- g1w5c47h6lta047h6lta047h6lta047h6ly5kscr
// - g1w5e97h6lta047h6lta047h6lta047h6lkdczk9
// - g1w5e47h6lta047h6lta047h6lta047h6lk7uxhr
// - g1w5697h6lta047h6lta047h6lta047h6lfnx389
// `
// 	if got != expected {
// 		t.Error(ufmt.Sprintf("expected:\n%v\ngot:\n%v\n", expected, got))
// 	}
// }
