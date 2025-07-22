package role

import (
	"testing"

	"gno.land/p/demo/testutils"
)

// NOTE: These tests focus on the business logic of role linking/unlinking.
// The cryptographic signature verification is tested separately in the claim tests.
// In a production environment, you would need to generate actual signed claims
// from the Discord bot.

func TestGetLinkedDiscordRole(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	// Test 1: Non-existent link should return empty LinkedRealmRole
	result := GetLinkedDiscordRole("gno.land/r/demo/app", "admin", "987654321098765432")
	if result.RealmPath != "" || result.RealmRoleName != "" || result.DiscordRoleID != "" || result.DiscordGuildID != "" {
		t.Errorf("non-existent link should return empty LinkedRealmRole, got: %+v", result)
	}

	// Test 2: Manually add a claim and verify retrieval
	alice := testutils.TestAddress("alice")
	claim := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim)

	result = GetLinkedDiscordRole("gno.land/r/demo/app", "admin", "987654321098765432")
	if result.RealmPath != "gno.land/r/demo/app" {
		t.Errorf("expected RealmPath 'gno.land/r/demo/app', got '%v'", result.RealmPath)
	}
	if result.RealmRoleName != "admin" {
		t.Errorf("expected RealmRoleName 'admin', got '%v'", result.RealmRoleName)
	}
	if result.DiscordRoleID != "111222333444555666" {
		t.Errorf("expected DiscordRoleID '111222333444555666', got '%v'", result.DiscordRoleID)
	}
	if result.DiscordGuildID != "987654321098765432" {
		t.Errorf("expected DiscordGuildID '987654321098765432', got '%v'", result.DiscordGuildID)
	}

	// Test 3: Different combination should return empty
	result = GetLinkedDiscordRole("gno.land/r/demo/app", "moderator", "987654321098765432")
	if result.RealmPath != "" {
		t.Errorf("different role name should return empty LinkedRealmRole")
	}
}

func TestGetLinkedDiscordRoleJSON(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	claim := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim)

	result := GetLinkedDiscordRoleJSON("gno.land/r/demo/app", "admin", "987654321098765432")
	expected := `{"RealmPath":"gno.land/r/demo/app","RealmRoleName":"admin","DiscordRoleID":"111222333444555666","DiscordGuildID":"987654321098765432"}`

	if result != expected {
		t.Errorf("expected JSON '%v', got '%v'", expected, result)
	}

	// Test empty result
	emptyResult := GetLinkedDiscordRoleJSON("nonexistent", "role", "999999999999999999")
	expectedEmpty := `{"RealmPath":"","RealmRoleName":"","DiscordRoleID":"","DiscordGuildID":""}`

	if emptyResult != expectedEmpty {
		t.Errorf("expected empty JSON '%v', got '%v'", expectedEmpty, emptyResult)
	}
}

func TestGetLinkedRealmRole(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	// Test 1: Non-existent combination should return empty LinkedRealmRole
	result := GetLinkedRealmRole("987654321098765432", "111222333444555666")
	if result.RealmPath != "" || result.RealmRoleName != "" || result.DiscordRoleID != "" || result.DiscordGuildID != "" {
		t.Errorf("non-existent combination should return empty LinkedRealmRole, got: %+v", result)
	}

	// Test 2: Manually add a claim and verify retrieval
	alice := testutils.TestAddress("alice")
	claim := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim)

	result = GetLinkedRealmRole("987654321098765432", "111222333444555666")
	if result.RealmPath != "gno.land/r/demo/app" {
		t.Errorf("expected RealmPath 'gno.land/r/demo/app', got '%v'", result.RealmPath)
	}
	if result.RealmRoleName != "admin" {
		t.Errorf("expected RealmRoleName 'admin', got '%v'", result.RealmRoleName)
	}
	if result.DiscordRoleID != "111222333444555666" {
		t.Errorf("expected DiscordRoleID '111222333444555666', got '%v'", result.DiscordRoleID)
	}
	if result.DiscordGuildID != "987654321098765432" {
		t.Errorf("expected DiscordGuildID '987654321098765432', got '%v'", result.DiscordGuildID)
	}

	// Test 3: Different combination should return empty
	result = GetLinkedRealmRole("987654321098765432", "999999999999999999")
	if result.RealmPath != "" {
		t.Errorf("different role ID should return empty LinkedRealmRole")
	}
}

func TestGetLinkedRealmRoleJSON(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	claim := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim)

	result := GetLinkedRealmRoleJSON("987654321098765432", "111222333444555666")
	expected := `{"RealmPath":"gno.land/r/demo/app","RealmRoleName":"admin","DiscordRoleID":"111222333444555666","DiscordGuildID":"987654321098765432"}`

	if result != expected {
		t.Errorf("expected JSON '%v', got '%v'", expected, result)
	}

	// Test empty result
	emptyResult := GetLinkedRealmRoleJSON("987654321098765432", "999999999999999999")
	expectedEmpty := `{"RealmPath":"","RealmRoleName":"","DiscordRoleID":"","DiscordGuildID":""}`

	if emptyResult != expectedEmpty {
		t.Errorf("expected empty JSON '%v', got '%v'", expectedEmpty, emptyResult)
	}
}

func TestListLinkedRoles(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Non-existent realm-guild should return empty slice
	result := ListLinkedRoles("gno.land/r/demo/app", "987654321098765432")
	if len(result) != 0 {
		t.Errorf("non-existent realm-guild should return empty slice, got: %v", result)
	}

	// Test 2: Add multiple roles for same realm-guild
	claim1 := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	claim2 := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "777888999000111222",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim1)
	ds.set(claim2)

	result = ListLinkedRoles("gno.land/r/demo/app", "987654321098765432")
	if len(result) != 2 {
		t.Errorf("expected 2 linked roles, got: %v", len(result))
	}

	// Check that both roles are present (order may vary)
	hasAdmin := false
	hasModerator := false
	for _, role := range result {
		if role.RealmRoleName == "admin" && role.DiscordRoleID == "111222333444555666" {
			hasAdmin = true
		}
		if role.RealmRoleName == "moderator" && role.DiscordRoleID == "777888999000111222" {
			hasModerator = true
		}
	}
	if !hasAdmin {
		t.Errorf("should contain admin role in results")
	}
	if !hasModerator {
		t.Errorf("should contain moderator role in results")
	}

	// Test 3: Different realm-guild should return empty
	result = ListLinkedRoles("gno.land/r/demo/app", "999999999999999999")
	if len(result) != 0 {
		t.Errorf("different guild should return empty, got: %v", result)
	}

	result = ListLinkedRoles("gno.land/r/demo/app2", "987654321098765432")
	if len(result) != 0 {
		t.Errorf("different realm should return empty, got: %v", result)
	}
}

func TestListLinkedRolesJSON(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Empty list should return empty JSON array
	result := ListLinkedRolesJSON("gno.land/r/demo/app", "987654321098765432")
	if result != "[]" {
		t.Errorf("empty list should return '[]', got '%v'", result)
	}

	// Test 2: Add roles and verify JSON
	claim1 := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	claim2 := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "777888999000111222",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app",
	}
	ds.set(claim1)
	ds.set(claim2)

	result = ListLinkedRolesJSON("gno.land/r/demo/app", "987654321098765432")

	// Should be a valid JSON array
	if result[0] != '[' || result[len(result)-1] != ']' {
		t.Errorf("result should be wrapped in square brackets, got: %v", result)
	}

	// Should contain both roles (order may vary)
	if !containsString(result, "admin") {
		t.Errorf("should contain admin role in JSON")
	}
	if !containsString(result, "moderator") {
		t.Errorf("should contain moderator role in JSON")
	}
	if !containsString(result, "111222333444555666") {
		t.Errorf("should contain 111222333444555666 ID in JSON")
	}
	if !containsString(result, "777888999000111222") {
		t.Errorf("should contain 777888999000111222 ID in JSON")
	}
}

func TestRoleBusinessLogicConstraints(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Cannot link same path-role-guild combination twice
	claim1 := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}

	err := ds.set(claim1)
	if err != nil {
		t.Errorf("first claim should succeed: %v", err)
	}

	claim2 := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "987654321098765432", // same guild
		discordRoleID:    "999888777666555444", // different discord role
		addr:             bob,
		roleName:         "admin",               // same realm role name
		realmPath:        "gno.land/r/demo/app", // same realm path
	}

	err = ds.set(claim2)
	if err == nil {
		t.Errorf("should fail when linking same realm-role-guild combination")
	}

	// Test 2: Cannot link same guild-role combination twice
	claim3 := &Claim{
		discordAccountID: "111222333444555666",
		discordGuildID:   "987654321098765432", // same guild
		discordRoleID:    "111222333444555666", // same discord role
		addr:             bob,
		roleName:         "moderator",            // different realm role
		realmPath:        "gno.land/r/demo/app2", // different realm
	}

	err = ds.set(claim3)
	if err == nil {
		t.Errorf("should fail when linking same guild-role combination")
	}

	// Test 3: Different combinations should succeed
	claim4 := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "444333222111000999", // different guild
		discordRoleID:    "333222111000999888", // different discord role
		addr:             bob,
		roleName:         "moderator",            // different realm role
		realmPath:        "gno.land/r/demo/app2", // different realm
	}

	err = ds.set(claim4)
	if err != nil {
		t.Errorf("different combination should succeed: %v", err)
	}
}

func TestRoleDatastoreRemovalConsistency(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Setup: Add multiple roles
	claimAdmin := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}
	claimMod := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "777888999000111222",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app",
	}

	ds.set(claimAdmin)
	ds.set(claimMod)

	// Verify both are present
	roles := ListLinkedRoles("gno.land/r/demo/app", "987654321098765432")
	if len(roles) != 2 {
		t.Errorf("expected 2 roles initially, got: %v", len(roles))
	}

	// Remove admin role using path-role-guild method
	ds.removeByPathRoleGuild("gno.land/r/demo/app", "admin", "987654321098765432")

	// Verify admin is completely removed but moderator remains
	adminResult := GetLinkedDiscordRole("gno.land/r/demo/app", "admin", "987654321098765432")
	if adminResult.RealmPath != "" {
		t.Errorf("admin should be completely removed")
	}

	modResult := GetLinkedDiscordRole("gno.land/r/demo/app", "moderator", "987654321098765432")
	if modResult.RealmPath == "" {
		t.Errorf("moderator should still exist")
	}

	// Verify role list is updated
	roles = ListLinkedRoles("gno.land/r/demo/app", "987654321098765432")
	if len(roles) != 1 {
		t.Errorf("expected 1 role after removal, got: %v", len(roles))
	}
	if roles[0].RealmRoleName != "moderator" {
		t.Errorf("remaining role should be moderator, got: %v", roles[0].RealmRoleName)
	}
}

// Note: Helper functions containsString and indexOfString are defined in claim_test.gno

func TestListAllRolesByGuild(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")
	charlie := testutils.TestAddress("charlie")

	// Test 1: Non-existent guild should return empty list
	result := ListAllRolesByGuild("987654321098765432")
	if len(result) != 0 {
		t.Errorf("non-existent guild should return empty list, got: %v", result)
	}

	// Test 2: Add roles from different realms for same guild
	claim1 := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app1",
	}
	claim2 := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "987654321098765432", // same guild
		discordRoleID:    "777888999000111222",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app2", // different realm
	}
	claim3 := &Claim{
		discordAccountID: "999888777666555444",
		discordGuildID:   "987654321098765432", // same guild
		discordRoleID:    "333222111000999888",
		addr:             charlie,
		roleName:         "user",
		realmPath:        "gno.land/r/demo/app1", // same realm as claim1
	}
	claim4 := &Claim{
		discordAccountID: "111222333444555666",
		discordGuildID:   "111111111111111111", // different guild
		discordRoleID:    "222222222222222222",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app3",
	}

	// Add all claims
	ds.set(claim1)
	ds.set(claim2)
	ds.set(claim3)
	ds.set(claim4)

	// Test 3: List all roles for guild 987654321098765432
	result = ListAllRolesByGuild("987654321098765432")
	if len(result) != 3 {
		t.Errorf("expected 3 roles for guild 987654321098765432, got: %v", len(result))
	}

	// Verify all expected roles are present
	foundRoles := make(map[string]bool)
	for _, role := range result {
		key := role.RealmPath + "|" + role.RealmRoleName
		foundRoles[key] = true
	}
	if !foundRoles["gno.land/r/demo/app1|admin"] {
		t.Errorf("should find app1 admin role")
	}
	if !foundRoles["gno.land/r/demo/app2|moderator"] {
		t.Errorf("should find app2 moderator role")
	}
	if !foundRoles["gno.land/r/demo/app1|user"] {
		t.Errorf("should find app1 user role")
	}

	// Test 4: List roles for guild 111111111111111111
	result = ListAllRolesByGuild("111111111111111111")
	if len(result) != 1 {
		t.Errorf("expected 1 role for guild 111111111111111111, got: %v", len(result))
	}
	if result[0].RealmPath != "gno.land/r/demo/app3" || result[0].RealmRoleName != "admin" {
		t.Errorf("unexpected role for guild 111111111111111111: %+v", result[0])
	}

	// Test 5: Empty guild ID should return empty list
	result = ListAllRolesByGuild("")
	if len(result) != 0 {
		t.Errorf("empty guild ID should return empty list, got: %v", result)
	}
}

func TestListAllRolesByGuildJSON(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Test 1: Empty guild should return empty JSON array
	result := ListAllRolesByGuildJSON("987654321098765432")
	if result != "[]" {
		t.Errorf("empty guild should return '[]', got '%v'", result)
	}

	// Test 2: Add roles and verify JSON
	claim1 := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app1",
	}
	claim2 := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "777888999000111222",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app2",
	}
	ds.set(claim1)
	ds.set(claim2)

	result = ListAllRolesByGuildJSON("987654321098765432")

	// Should be a valid JSON array
	if result[0] != '[' || result[len(result)-1] != ']' {
		t.Errorf("result should be wrapped in square brackets, got: %v", result)
	}

	// Should contain both roles
	if !containsString(result, "admin") {
		t.Errorf("should contain admin role in JSON")
	}
	if !containsString(result, "moderator") {
		t.Errorf("should contain moderator role in JSON")
	}
	if !containsString(result, "gno.land/r/demo/app1") {
		t.Errorf("should contain app1 realm path in JSON")
	}
	if !containsString(result, "gno.land/r/demo/app2") {
		t.Errorf("should contain app2 realm path in JSON")
	}
}

func TestListAllRolesByGuildAfterRemoval(t *testing.T) {
	// Reset datastore for test isolation
	ds = newDatastore()

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	// Setup: Add roles
	claim1 := &Claim{
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             alice,
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app1",
	}
	claim2 := &Claim{
		discordAccountID: "555666777888999000",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "777888999000111222",
		addr:             bob,
		roleName:         "moderator",
		realmPath:        "gno.land/r/demo/app2",
	}
	ds.set(claim1)
	ds.set(claim2)

	// Verify initial state
	result := ListAllRolesByGuild("987654321098765432")
	if len(result) != 2 {
		t.Errorf("expected 2 roles initially, got: %v", len(result))
	}

	// Remove admin role
	ds.removeByPathRoleGuild("gno.land/r/demo/app1", "admin", "987654321098765432")

	// Verify list is updated
	result = ListAllRolesByGuild("987654321098765432")
	if len(result) != 1 {
		t.Errorf("expected 1 role after removal, got: %v", len(result))
	}
	if result[0].RealmPath != "gno.land/r/demo/app2" || result[0].RealmRoleName != "moderator" {
		t.Errorf("remaining role should be app2 moderator, got: %+v", result[0])
	}

	// Remove moderator role
	ds.removeByGuildRole("987654321098765432", "777888999000111222")

	// Verify list is empty
	result = ListAllRolesByGuild("987654321098765432")
	if len(result) != 0 {
		t.Errorf("expected empty list after removing all roles, got: %v", len(result))
	}
}
