package user

import (
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
)

// TestDatastoreSet tests the set method with various scenarios
func TestDatastoreSet(t *testing.T) {
	ds := datastore{
		byAddr:      avl.NewTree(),
		byDiscordID: avl.NewTree(),
	}

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: First valid claim should succeed
	claim1 := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123",
		addr:      alice,
	}

	err := ds.set(claim1)
	if err != nil {
		t.Errorf("first claim should succeed: %v", err)
	}

	// Test 2: Cannot link same address twice
	claim2 := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_456",
		addr:      alice, // same address
	}

	err = ds.set(claim2)
	if err == nil {
		t.Errorf("should fail when linking same address twice")
	}
	if err.Error() != "datastore: gno address is already linked" {
		t.Errorf("expected 'gno address is already linked' error, got: %v", err)
	}

	// Test 3: Cannot link same discord ID twice
	claim3 := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123", // same discord ID
		addr:      bob,
	}

	err = ds.set(claim3)
	if err == nil {
		t.Errorf("should fail when linking same discord ID twice")
	}
	if err.Error() != "datastore: discord id is already linked" {
		t.Errorf("expected 'discord id is already linked' error, got: %v", err)
	}

	// Test 4: Different address and discord ID should succeed
	claim4 := &Claim{
		timestamp: time.Now(),
		discordID: "bob_discord_789",
		addr:      bob,
	}

	err = ds.set(claim4)
	if err != nil {
		t.Errorf("claim with different address and discord ID should succeed: %v", err)
	}
}

// TestDatastoreGetByAddress tests address-based lookups
func TestDatastoreGetByAddress(t *testing.T) {
	ds := datastore{
		byAddr:      avl.NewTree(),
		byDiscordID: avl.NewTree(),
	}

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Non-existent address should return nil
	result := ds.getByAddress(alice)
	if result != nil {
		t.Errorf("non-existent address should return nil, got: %v", result)
	}

	// Test 2: Add claim and verify retrieval
	claim := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123",
		addr:      alice,
	}
	ds.set(claim)

	result = ds.getByAddress(alice)
	if result == nil {
		t.Errorf("should find claim for alice")
	}
	if result.discordID != "alice_discord_123" {
		t.Errorf("expected discord ID 'alice_discord_123', got: %v", result.discordID)
	}
	if result.addr != alice {
		t.Errorf("expected address %v, got: %v", alice, result.addr)
	}

	// Test 3: Different address should still return nil
	result = ds.getByAddress(bob)
	if result != nil {
		t.Errorf("bob should not have a claim, got: %v", result)
	}
}

// TestDatastoreGetByDiscordID tests discord ID-based lookups
func TestDatastoreGetByDiscordID(t *testing.T) {
	ds := datastore{
		byAddr:      avl.NewTree(),
		byDiscordID: avl.NewTree(),
	}

	alice := testutils.TestAddress("alice")

	// Test 1: Non-existent discord ID should return nil
	result := ds.getByDiscordID("nonexistent_discord")
	if result != nil {
		t.Errorf("non-existent discord ID should return nil, got: %v", result)
	}

	// Test 2: Add claim and verify retrieval
	claim := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123",
		addr:      alice,
	}
	ds.set(claim)

	result = ds.getByDiscordID("alice_discord_123")
	if result == nil {
		t.Errorf("should find claim for alice_discord_123")
	}
	if result.discordID != "alice_discord_123" {
		t.Errorf("expected discord ID 'alice_discord_123', got: %v", result.discordID)
	}
	if result.addr != alice {
		t.Errorf("expected address %v, got: %v", alice, result.addr)
	}

	// Test 3: Different discord ID should return nil
	result = ds.getByDiscordID("bob_discord_456")
	if result != nil {
		t.Errorf("bob_discord_456 should not exist, got: %v", result)
	}
}

// TestDatastoreRemoveByAddress tests removal by address
func TestDatastoreRemoveByAddress(t *testing.T) {
	ds := datastore{
		byAddr:      avl.NewTree(),
		byDiscordID: avl.NewTree(),
	}

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Setup: Add two claims
	claim1 := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123",
		addr:      alice,
	}
	claim2 := &Claim{
		timestamp: time.Now(),
		discordID: "bob_discord_456",
		addr:      bob,
	}
	ds.set(claim1)
	ds.set(claim2)

	// Test 1: Remove alice by address
	ds.removeByAddress(alice)

	// Verify alice is removed from both indices
	if ds.getByAddress(alice) != nil {
		t.Errorf("alice should be removed from address index")
	}
	if ds.getByDiscordID("alice_discord_123") != nil {
		t.Errorf("alice_discord_123 should be removed from discord index")
	}

	// Verify bob is still there
	if ds.getByAddress(bob) == nil {
		t.Errorf("bob should still exist")
	}
	if ds.getByDiscordID("bob_discord_456") == nil {
		t.Errorf("bob_discord_456 should still exist")
	}

	// Test 2: Remove non-existent address (should not panic)
	charlie := testutils.TestAddress("charlie")
	ds.removeByAddress(charlie) // Should not panic
}

// TestDatastoreRemoveByDiscordID tests removal by discord ID
func TestDatastoreRemoveByDiscordID(t *testing.T) {
	ds := datastore{
		byAddr:      avl.NewTree(),
		byDiscordID: avl.NewTree(),
	}

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Setup: Add two claims
	claim1 := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123",
		addr:      alice,
	}
	claim2 := &Claim{
		timestamp: time.Now(),
		discordID: "bob_discord_456",
		addr:      bob,
	}
	ds.set(claim1)
	ds.set(claim2)

	// Test 1: Remove alice by discord ID
	ds.removeByDiscordID("alice_discord_123")

	// Verify alice is removed from both indices
	if ds.getByAddress(alice) != nil {
		t.Errorf("alice should be removed from address index")
	}
	if ds.getByDiscordID("alice_discord_123") != nil {
		t.Errorf("alice_discord_123 should be removed from discord index")
	}

	// Verify bob is still there
	if ds.getByAddress(bob) == nil {
		t.Errorf("bob should still exist")
	}
	if ds.getByDiscordID("bob_discord_456") == nil {
		t.Errorf("bob_discord_456 should still exist")
	}

	// Test 2: Remove non-existent discord ID (should not panic)
	ds.removeByDiscordID("nonexistent_discord") // Should not panic
}

// TestDatastoreComplexScenario tests a complex scenario with multiple operations
func TestDatastoreComplexScenario(t *testing.T) {
	ds := datastore{
		byAddr:      avl.NewTree(),
		byDiscordID: avl.NewTree(),
	}

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")
	charlie := testutils.TestAddress("charlie")

	// Step 1: Add alice
	claimAlice := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123",
		addr:      alice,
	}
	err := ds.set(claimAlice)
	if err != nil {
		t.Errorf("adding alice should succeed: %v", err)
	}

	// Step 2: Try to add bob with alice's discord ID (should fail)
	claimBob := &Claim{
		timestamp: time.Now(),
		discordID: "alice_discord_123", // same discord ID
		addr:      bob,
	}
	err = ds.set(claimBob)
	if err == nil {
		t.Errorf("should fail when using alice's discord ID")
	}

	// Step 3: Remove alice and try again (should succeed)
	ds.removeByAddress(alice)
	err = ds.set(claimBob)
	if err != nil {
		t.Errorf("should succeed after alice is removed: %v", err)
	}

	// Step 4: Verify bob has the discord ID now
	result := ds.getByDiscordID("alice_discord_123")
	if result == nil {
		t.Errorf("should find claim for alice_discord_123")
	}
	if result.addr != bob {
		t.Errorf("discord ID should now belong to bob, got: %v", result.addr)
	}

	// Step 5: Add charlie with different discord ID
	claimCharlie := &Claim{
		timestamp: time.Now(),
		discordID: "charlie_discord_789",
		addr:      charlie,
	}
	err = ds.set(claimCharlie)
	if err != nil {
		t.Errorf("adding charlie should succeed: %v", err)
	}

	// Step 6: Verify all current state
	if ds.getByAddress(alice) != nil {
		t.Errorf("alice should not exist")
	}
	if ds.getByAddress(bob) == nil {
		t.Errorf("bob should exist")
	}
	if ds.getByAddress(charlie) == nil {
		t.Errorf("charlie should exist")
	}
}
