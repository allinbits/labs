package role

import (
	"testing"
	"time"

	"gno.land/p/demo/testutils"
)

// TestNewDatastore tests datastore creation
func TestNewDatastore(t *testing.T) {
	ds := newDatastore()

	if ds == nil {
		t.Errorf("newDatastore should return a valid datastore")
	}
	if ds.byPathRoleGuild == nil {
		t.Errorf("byPathRoleGuild should be initialized")
	}
	if ds.byGuildRole == nil {
		t.Errorf("byGuildRole should be initialized")
	}
	if ds.byPathGuild == nil {
		t.Errorf("byPathGuild should be initialized")
	}
}

// TestDatastoreSet tests the set method with various scenarios
func TestDatastoreSet(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Setting nil claim should fail
	err := ds.set(nil)
	if err == nil {
		t.Errorf("setting nil claim should fail")
	}
	if err.Error() != "datastore: cannot set nil claim" {
		t.Errorf("expected 'cannot set nil claim' error, got: %v", err)
	}

	// Test 2: First valid claim should succeed
	claim1 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role789",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}

	err = ds.set(claim1)
	if err != nil {
		t.Errorf("first claim should succeed: %v", err)
	}

	// Test 3: Cannot link same path-role-guild combination twice
	claim2 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user456",
		discordGuildID:   "guild456", // same guild
		discordRoleID:    "role999",  // different role ID
		addr:             bob,
		roleName:         "admin",               // same role name
		realmPath:        "gno.land/r/demo/app", // same realm path
	}

	err = ds.set(claim2)
	if err == nil {
		t.Errorf("should fail when linking same path-role-guild combination")
	}
	if err.Error() != "datastore: the unique path-role-guild key is already linked" {
		t.Errorf("expected 'path-role-guild key is already linked' error, got: %v", err)
	}

	// Test 4: Cannot link same guild-role combination twice
	claim3 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user789",
		discordGuildID:   "guild456", // same guild
		discordRoleID:    "role789",  // same role ID
		addr:             bob,
		roleName:         "moderator",            // different role name
		realmPath:        "gno.land/r/demo/app2", // different realm path
	}

	err = ds.set(claim3)
	if err == nil {
		t.Errorf("should fail when linking same guild-role combination")
	}
	if err.Error() != "datastore: the unique guild-role key is already linked" {
		t.Errorf("expected 'guild-role key is already linked' error, got: %v", err)
	}

	// Test 5: Different combination should succeed
	claim4 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user456",
		discordGuildID:   "guild789", // different guild
		discordRoleID:    "role123",  // different role ID
		addr:             bob,
		roleName:         "moderator",            // different role name
		realmPath:        "gno.land/r/demo/app2", // different realm path
	}

	err = ds.set(claim4)
	if err != nil {
		t.Errorf("claim with different path-role-guild and guild-role should succeed: %v", err)
	}
}

// TestDatastoreGetByPathRoleGuild tests path-role-guild based lookups
func TestDatastoreGetByPathRoleGuild(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")

	// Test 1: Non-existent combination should return nil
	result := ds.getByPathRoleGuild("gno.land/r/demo/app", "admin", "guild456")
	if result != nil {
		t.Errorf("non-existent combination should return nil, got: %v", result)
	}

	// Test 2: Add claim and verify retrieval
	claim := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role789",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim)

	result = ds.getByPathRoleGuild("gno.land/r/demo/app", "admin", "guild456")
	if result == nil {
		t.Errorf("should find claim for gno.land/r/demo/app|admin|guild456")
	}
	if result.discordRoleID != "role789" {
		t.Errorf("expected role ID 'role789', got: %v", result.discordRoleID)
	}
	if result.addr != alice {
		t.Errorf("expected address %v, got: %v", alice, result.addr)
	}

	// Test 3: Different combination should return nil
	result = ds.getByPathRoleGuild("gno.land/r/demo/app", "moderator", "guild456")
	if result != nil {
		t.Errorf("different role name should return nil, got: %v", result)
	}

	result = ds.getByPathRoleGuild("gno.land/r/demo/app", "admin", "guild999")
	if result != nil {
		t.Errorf("different guild should return nil, got: %v", result)
	}
}

// TestDatastoreGetByGuildRole tests guild-role based lookups
func TestDatastoreGetByGuildRole(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")

	// Test 1: Non-existent combination should return nil
	result := ds.getByGuildRole("guild456", "role789")
	if result != nil {
		t.Errorf("non-existent combination should return nil, got: %v", result)
	}

	// Test 2: Add claim and verify retrieval
	claim := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role789",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim)

	result = ds.getByGuildRole("guild456", "role789")
	if result == nil {
		t.Errorf("should find claim for guild456|role789")
	}
	if result.roleName != "admin" {
		t.Errorf("expected role name 'admin', got: %v", result.roleName)
	}
	if result.realmPath != "gno.land/r/demo/app" {
		t.Errorf("expected realm path 'gno.land/r/demo/app', got: %v", result.realmPath)
	}

	// Test 3: Different combination should return nil
	result = ds.getByGuildRole("guild456", "role999")
	if result != nil {
		t.Errorf("different role ID should return nil, got: %v", result)
	}

	result = ds.getByGuildRole("guild999", "role789")
	if result != nil {
		t.Errorf("different guild should return nil, got: %v", result)
	}
}

// TestDatastoreRemoveByPathRoleGuild tests removal by path-role-guild
func TestDatastoreRemoveByPathRoleGuild(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Setup: Add two claims
	claim1 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role789",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	claim2 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user456",
		discordGuildID:   "guild789",
		discordRoleID:    "role123",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app2",
	}
	ds.set(claim1)
	ds.set(claim2)

	// Test 1: Remove first claim by path-role-guild
	ds.removeByPathRoleGuild("gno.land/r/demo/app", "admin", "guild456")

	// Verify claim1 is removed from both indices
	if ds.getByPathRoleGuild("gno.land/r/demo/app", "admin", "guild456") != nil {
		t.Errorf("claim1 should be removed from path-role-guild index")
	}
	if ds.getByGuildRole("guild456", "role789") != nil {
		t.Errorf("claim1 should be removed from guild-role index")
	}

	// Verify claim2 is still there
	if ds.getByPathRoleGuild("gno.land/r/demo/app2", "moderator", "guild789") == nil {
		t.Errorf("claim2 should still exist")
	}
	if ds.getByGuildRole("guild789", "role123") == nil {
		t.Errorf("claim2 should still exist in guild-role index")
	}

	// Test 2: Remove non-existent combination (should not panic)
	ds.removeByPathRoleGuild("nonexistent", "role", "guild")
}

// TestDatastoreRemoveByGuildRole tests removal by guild-role
func TestDatastoreRemoveByGuildRole(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Setup: Add two claims
	claim1 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role789",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	claim2 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user456",
		discordGuildID:   "guild789",
		discordRoleID:    "role123",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app2",
	}
	ds.set(claim1)
	ds.set(claim2)

	// Test 1: Remove first claim by guild-role
	ds.removeByGuildRole("guild456", "role789")

	// Verify claim1 is removed from both indices
	if ds.getByGuildRole("guild456", "role789") != nil {
		t.Errorf("claim1 should be removed from guild-role index")
	}
	if ds.getByPathRoleGuild("gno.land/r/demo/app", "admin", "guild456") != nil {
		t.Errorf("claim1 should be removed from path-role-guild index")
	}

	// Verify claim2 is still there
	if ds.getByGuildRole("guild789", "role123") == nil {
		t.Errorf("claim2 should still exist")
	}
	if ds.getByPathRoleGuild("gno.land/r/demo/app2", "moderator", "guild789") == nil {
		t.Errorf("claim2 should still exist in path-role-guild index")
	}

	// Test 2: Remove non-existent combination (should not panic)
	ds.removeByGuildRole("nonexistent", "role")
}

// TestDatastoreListRolesByPathGuild tests listing roles for a path-guild combination
func TestDatastoreListRolesByPathGuild(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Non-existent path-guild should return empty slice
	result := ds.listRolesByPathGuild("gno.land/r/demo/app", "guild456")
	if len(result) != 0 {
		t.Errorf("non-existent path-guild should return empty slice, got: %v", result)
	}

	// Test 2: Add multiple roles for same path-guild
	claim1 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role789",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	claim2 := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user456",
		discordGuildID:   "guild456", // same guild
		discordRoleID:    "role123",
		addr:             bob,
		roleName:         "moderator",           // different role
		realmPath:        "gno.land/r/demo/app", // same realm
	}
	ds.set(claim1)
	ds.set(claim2)

	result = ds.listRolesByPathGuild("gno.land/r/demo/app", "guild456")
	if len(result) != 2 {
		t.Errorf("expected 2 roles for gno.land/r/demo/app|guild456, got: %v", len(result))
	}

	// Check both roles are present (order may vary)
	hasAdmin := false
	hasModerator := false
	for _, role := range result {
		if role == "admin" {
			hasAdmin = true
		}
		if role == "moderator" {
			hasModerator = true
		}
	}
	if !hasAdmin {
		t.Errorf("should contain 'admin' role in results: %v", result)
	}
	if !hasModerator {
		t.Errorf("should contain 'moderator' role in results: %v", result)
	}

	// Test 3: Different path-guild should return empty
	result = ds.listRolesByPathGuild("gno.land/r/demo/app", "guild999")
	if len(result) != 0 {
		t.Errorf("different guild should return empty, got: %v", result)
	}

	result = ds.listRolesByPathGuild("gno.land/r/demo/app2", "guild456")
	if len(result) != 0 {
		t.Errorf("different realm should return empty, got: %v", result)
	}
}

// TestDatastorePathGuildOperations tests the path-guild role tracking
func TestDatastorePathGuildOperations(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")

	// Test adding and removing roles from path-guild tracking
	claim := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role789",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}

	// Add claim
	ds.set(claim)

	// Verify role is tracked
	roles := ds.listRolesByPathGuild("gno.land/r/demo/app", "guild456")
	if len(roles) != 1 || roles[0] != "admin" {
		t.Errorf("expected ['admin'], got: %v", roles)
	}

	// Remove by path-role-guild
	ds.removeByPathRoleGuild("gno.land/r/demo/app", "admin", "guild456")

	// Verify role is no longer tracked
	roles = ds.listRolesByPathGuild("gno.land/r/demo/app", "guild456")
	if len(roles) != 0 {
		t.Errorf("expected empty slice after removal, got: %v", roles)
	}
}

// TestDatastoreComplexScenario tests a complex scenario with multiple operations
func TestDatastoreComplexScenario(t *testing.T) {
	ds := newDatastore()
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")
	charlie := testutils.TestAddress("charlie")

	// Step 1: Add multiple claims for same realm-guild but different roles
	claimAdmin := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user123",
		discordGuildID:   "guild456",
		discordRoleID:    "role_admin",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	claimMod := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user456",
		discordGuildID:   "guild456",
		discordRoleID:    "role_mod",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app",
	}
	claimUser := &Claim{
		timestamp:        time.Now(),
		discordAccountID: "user789",
		discordGuildID:   "guild456",
		discordRoleID:    "role_user",
		addr:             charlie,
		roleName:         "user",
		realmPath:        "gno.land/r/demo/app",
	}

	err := ds.set(claimAdmin)
	if err != nil {
		t.Errorf("adding admin claim should succeed: %v", err)
	}
	err = ds.set(claimMod)
	if err != nil {
		t.Errorf("adding moderator claim should succeed: %v", err)
	}
	err = ds.set(claimUser)
	if err != nil {
		t.Errorf("adding user claim should succeed: %v", err)
	}

	// Step 2: Verify all roles are tracked
	roles := ds.listRolesByPathGuild("gno.land/r/demo/app", "guild456")
	if len(roles) != 3 {
		t.Errorf("expected 3 roles, got: %v", len(roles))
	}

	// Step 3: Verify lookups work in both directions
	adminClaim := ds.getByGuildRole("guild456", "role_admin")
	if adminClaim == nil || adminClaim.roleName != "admin" {
		t.Errorf("should find admin claim by guild-role")
	}

	modClaim := ds.getByPathRoleGuild("gno.land/r/demo/app", "moderator", "guild456")
	if modClaim == nil || modClaim.discordRoleID != "role_mod" {
		t.Errorf("should find moderator claim by path-role-guild")
	}

	// Step 4: Remove moderator role
	ds.removeByGuildRole("guild456", "role_mod")

	// Step 5: Verify moderator is gone but others remain
	roles = ds.listRolesByPathGuild("gno.land/r/demo/app", "guild456")
	if len(roles) != 2 {
		t.Errorf("expected 2 roles after removal, got: %v", len(roles))
	}

	if ds.getByGuildRole("guild456", "role_mod") != nil {
		t.Errorf("moderator should be removed")
	}
	if ds.getByPathRoleGuild("gno.land/r/demo/app", "moderator", "guild456") != nil {
		t.Errorf("moderator should be removed from path-role-guild index")
	}

	// Admin and user should still exist
	if ds.getByGuildRole("guild456", "role_admin") == nil {
		t.Errorf("admin should still exist")
	}
	if ds.getByGuildRole("guild456", "role_user") == nil {
		t.Errorf("user should still exist")
	}
}
