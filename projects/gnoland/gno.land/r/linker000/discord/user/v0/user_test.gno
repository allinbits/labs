package user

import (
	"testing"

	"gno.land/p/demo/testutils"
)

// NOTE: These tests focus on the business logic of linking/unlinking.
// The cryptographic signature verification is tested separately in the claim tests.
// In a production environment, you would need to generate actual signed claims
// from the Discord bot.

func TestUnlinkByCaller(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	// Test that a caller can unlink their own discord connection
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")
	charlie := testutils.TestAddress("charlie")

	// Manually set up some test data in the datastore
	// In production, this would be done via Link() with valid claims
	ds.set(&Claim{
		discordID: "123456789012345678",
		addr:      alice,
	})
	ds.set(&Claim{
		discordID: "987654321098765432",
		addr:      bob,
	})

	// Test alice unlinking herself
	testing.SetOriginCaller(alice)
	UnlinkByCaller(cross)

	// Verify alice is unlinked
	if GetLinkedDiscordID(alice) != "" {
		t.Errorf("alice should be unlinked")
	}
	if GetLinkedAddress("123456789012345678") != "" {
		t.Errorf("123456789012345678 should not be linked to any address")
	}

	// Verify bob is still linked
	if GetLinkedDiscordID(bob) != "987654321098765432" {
		t.Errorf("bob should still be linked")
	}

	// Test unlinking when not linked (should not panic)
	testing.SetOriginCaller(charlie)
	UnlinkByCaller(cross) // Should not panic
}

func TestGetLinkedAddress(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")

	// Test before any links
	addr := GetLinkedAddress("nonexistent_discord")
	if addr != "" {
		t.Errorf("expected empty address for nonexistent discord ID, got: %v", addr)
	}

	// Manually add a link for testing
	ds.set(&Claim{
		discordID: "123456789012345678",
		addr:      alice,
	})

	// Test after link
	addr = GetLinkedAddress("123456789012345678")
	if addr != alice {
		t.Errorf("expected address: %v, got: %v", alice, addr)
	}

	// Test with different discord ID
	addr = GetLinkedAddress("999999999999999999")
	if addr != "" {
		t.Errorf("expected empty address for unlinked discord ID, got: %v", addr)
	}
}

func TestGetLinkedDiscordID(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test before any links
	discordID := GetLinkedDiscordID(alice)
	if discordID != "" {
		t.Errorf("expected empty discord ID for unlinked address, got: %v", discordID)
	}

	// Manually add a link for testing
	ds.set(&Claim{
		discordID: "123456789012345678",
		addr:      alice,
	})

	// Test after link
	discordID = GetLinkedDiscordID(alice)
	if discordID != "123456789012345678" {
		t.Errorf("expected discord ID: 123456789012345678, got: %v", discordID)
	}

	// Test with different address
	discordID = GetLinkedDiscordID(bob)
	if discordID != "" {
		t.Errorf("expected empty discord ID for unlinked address, got: %v", discordID)
	}
}

func TestDatastoreConstraints(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Cannot link same address twice
	err := ds.set(&Claim{
		discordID: "123456789012345678",
		addr:      alice,
	})
	if err != nil {
		t.Errorf("first link should succeed: %v", err)
	}

	err = ds.set(&Claim{
		discordID: "987654321098765432",
		addr:      alice,
	})
	if err == nil || err.Error() != "datastore: gno address is already linked" {
		t.Errorf("expected address already linked error, got: %v", err)
	}

	// Test 2: Cannot link same discord ID twice
	err = ds.set(&Claim{
		discordID: "123456789012345678",
		addr:      bob,
	})
	if err == nil || err.Error() != "datastore: discord id is already linked" {
		t.Errorf("expected discord id already linked error, got: %v", err)
	}

	// Test 3: Removal by address works correctly
	ds.removeByAddress(alice)
	if ds.getByAddress(alice) != nil {
		t.Errorf("address should be removed")
	}
	if ds.getByDiscordID("123456789012345678") != nil {
		t.Errorf("discord ID should be removed when address is removed")
	}

	// Test 4: Can link the same discord ID after removal
	err = ds.set(&Claim{
		discordID: "123456789012345678",
		addr:      bob,
	})
	if err != nil {
		t.Errorf("should be able to link discord ID after removal: %v", err)
	}
}

// TODO: Add integration tests with actual signed claims from the Discord bot
// These would test the full flow including signature verification
