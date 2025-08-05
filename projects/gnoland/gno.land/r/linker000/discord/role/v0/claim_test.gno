package role

import (
	"testing"

	"gno.land/p/demo/testutils"
)

// TestVerifyBlockHeight tests block height validation logic
func TestVerifyBlockHeight(t *testing.T) {
	tt := []struct {
		claimHeight  int64
		currentHeight int64
		shouldFail   bool
		expectedErr  string
		description  string
	}{
		{
			claimHeight:  1000,
			currentHeight: 1050,
			shouldFail:   false,
			description:  "claim within maxBlockAge should pass",
		},
		{
			claimHeight:  1000,
			currentHeight: 1499,
			shouldFail:   false,
			description:  "claim near maxBlockAge limit should pass",
		},
		{
			claimHeight:  1000,
			currentHeight: 1501,
			shouldFail:   true,
			expectedErr:  "claim: block height too old (age: 501 blocks, max: 500 blocks, claim: 1000, current: 1501)",
			description:  "claim exceeding maxBlockAge should fail",
		},
		{
			claimHeight:  2000,
			currentHeight: 1999,
			shouldFail:   true,
			expectedErr:  "claim: block height is in the future (claim: 2000, current: 1999)",
			description:  "claim from future block should fail",
		},
		{
			claimHeight:  1000,
			currentHeight: 1000,
			shouldFail:   false,
			description:  "claim at exact same block should pass",
		},
		{
			claimHeight:  0,
			currentHeight: 100,
			shouldFail:   false,
			description:  "genesis block claim should pass if within age limit",
		},
	}

	for _, test := range tt {
		err := verifyBlockHeight(test.claimHeight, test.currentHeight)

		if test.shouldFail {
			if err == nil {
				t.Errorf("expected error for claimHeight=%v, currentHeight=%v, description: %v",
					test.claimHeight, test.currentHeight, test.description)
				continue
			}
			if err.Error() != test.expectedErr {
				t.Errorf("expected error '%v', got '%v', description: %v",
					test.expectedErr, err.Error(), test.description)
			}
			continue
		}

		if err != nil {
			t.Errorf("unexpected error for claimHeight=%v, currentHeight=%v: %v, description: %v",
				test.claimHeight, test.currentHeight, err, test.description)
		}
	}
}

// TestClaimMethods tests the methods on Claim struct
func TestClaimMethods(t *testing.T) {
	claim := &Claim{
		blockHeight:      1000,
		discordAccountID: "123456789012345678",
		discordGuildID:   "987654321098765432",
		discordRoleID:    "111222333444555666",
		addr:             testutils.TestAddress("alice"),
		roleName:         "admin",
		realmPath:        "gno.land/r/demo/app",
	}

	// Test PathRoleGuildKey
	expected := "gno.land/r/demo/app|admin|987654321098765432"
	result := claim.PathRoleGuildKey()
	if result != expected {
		t.Errorf("PathRoleGuildKey: expected '%v', got '%v'", expected, result)
	}

	// Test GuildRoleKey
	expected = "987654321098765432|111222333444555666"
	result = claim.GuildRoleKey()
	if result != expected {
		t.Errorf("GuildRoleKey: expected '%v', got '%v'", expected, result)
	}

	// Test RoleID
	result = claim.RoleID()
	if result != "111222333444555666" {
		t.Errorf("RoleID: expected '111222333444555666', got '%v'", result)
	}

	// Test RealmRoleDetails
	details := claim.RealmRoleDetails()
	if details.RealmPath != "gno.land/r/demo/app" {
		t.Errorf("RealmRoleDetails.RealmPath: expected 'gno.land/r/demo/app', got '%v'", details.RealmPath)
	}
	if details.RealmRoleName != "admin" {
		t.Errorf("RealmRoleDetails.RealmRoleName: expected 'admin', got '%v'", details.RealmRoleName)
	}
	if details.DiscordRoleID != "111222333444555666" {
		t.Errorf("RealmRoleDetails.DiscordRoleID: expected '111222333444555666', got '%v'", details.DiscordRoleID)
	}
	if details.DiscordGuildID != "987654321098765432" {
		t.Errorf("RealmRoleDetails.DiscordGuildID: expected '987654321098765432', got '%v'", details.DiscordGuildID)
	}
}

// TestFormatFunctions tests the key formatting functions
func TestFormatFunctions(t *testing.T) {
	// Test fmtPathGuildKey
	result := fmtPathGuildKey("gno.land/r/demo/app", "guild123")
	expected := "gno.land/r/demo/app|guild123"
	if result != expected {
		t.Errorf("fmtPathGuildKey: expected '%v', got '%v'", expected, result)
	}

	// Test fmtPathRoleGuildKey
	result = fmtPathRoleGuildKey("gno.land/r/demo/app", "admin", "guild123")
	expected = "gno.land/r/demo/app|admin|guild123"
	if result != expected {
		t.Errorf("fmtPathRoleGuildKey: expected '%v', got '%v'", expected, result)
	}

	// Test fmtGuildRoleKey
	result = fmtGuildRoleKey("guild123", "role456")
	expected = "guild123|role456"
	if result != expected {
		t.Errorf("fmtGuildRoleKey: expected '%v', got '%v'", expected, result)
	}

	// Test with empty values
	result = fmtPathGuildKey("", "")
	expected = "|"
	if result != expected {
		t.Errorf("fmtPathGuildKey with empty values: expected '%v', got '%v'", expected, result)
	}
}

// TestSignatureUsageTracking tests signature replay protection
func TestSignatureUsageTracking(t *testing.T) {
	// Initialize a test datastore
	ds := newDatastore()

	// Test 1: New signature should not be used
	sig1 := "test_signature_1"
	if ds.isSignatureUsed(sig1) {
		t.Errorf("new signature should not be marked as used")
	}

	// Test 2: Mark signature as used
	ds.markSignatureUsed(sig1, 1000)
	if !ds.isSignatureUsed(sig1) {
		t.Errorf("signature should be marked as used after calling markSignatureUsed")
	}

	// Test 3: Different signature should not be affected
	sig2 := "test_signature_2"
	if ds.isSignatureUsed(sig2) {
		t.Errorf("different signature should not be marked as used")
	}

	// Test 4: Mark second signature and verify both are tracked
	ds.markSignatureUsed(sig2, 1001)
	if !ds.isSignatureUsed(sig1) || !ds.isSignatureUsed(sig2) {
		t.Errorf("both signatures should be marked as used")
	}
}

// TestLinkedRealmRoleToJSON tests JSON serialization
func TestLinkedRealmRoleToJSON(t *testing.T) {
	lrr := LinkedRealmRole{
		RealmPath:      "gno.land/r/demo/app",
		RealmRoleName:  "admin",
		DiscordRoleID:  "role123",
		DiscordGuildID: "guild456",
	}

	result := lrr.ToJSON()
	expected := `{"RealmPath":"gno.land/r/demo/app","RealmRoleName":"admin","DiscordRoleID":"role123","DiscordGuildID":"guild456"}`

	if result != expected {
		t.Errorf("ToJSON: expected '%v', got '%v'", expected, result)
	}

	// Test with special characters that need escaping
	lrrSpecial := LinkedRealmRole{
		RealmPath:      "gno.land/r/demo/\"test\"",
		RealmRoleName:  "admin\\test",
		DiscordRoleID:  "role\n123",
		DiscordGuildID: "guild\t456",
	}

	result = lrrSpecial.ToJSON()
	// Should escape quotes, backslashes, newlines, and tabs
	if !containsString(result, "\\\"test\\\"") {
		t.Errorf("should escape quotes in RealmPath")
	}
	if !containsString(result, "admin\\\\test") {
		t.Errorf("should escape backslashes in RealmRoleName")
	}
	if !containsString(result, "role\\n123") {
		t.Errorf("should escape newlines in DiscordRoleID")
	}
	if !containsString(result, "guild\\t456") {
		t.Errorf("should escape tabs in DiscordGuildID")
	}
}

// TestLinkedRealmRolesToJSON tests JSON array serialization
func TestLinkedRealmRolesToJSON(t *testing.T) {
	roles := []LinkedRealmRole{
		{
			RealmPath:      "gno.land/r/demo/app1",
			RealmRoleName:  "admin",
			DiscordRoleID:  "role123",
			DiscordGuildID: "guild456",
		},
		{
			RealmPath:      "gno.land/r/demo/app2",
			RealmRoleName:  "moderator",
			DiscordRoleID:  "role789",
			DiscordGuildID: "guild456",
		},
	}

	result := linkedRealmRolesToJSON(roles)

	// Should be a valid JSON array
	if result[0] != '[' || result[len(result)-1] != ']' {
		t.Errorf("result should be wrapped in square brackets")
	}

	// Should contain both roles
	if !containsString(result, "app1") {
		t.Errorf("should contain first role")
	}
	if !containsString(result, "app2") {
		t.Errorf("should contain second role")
	}
	if !containsString(result, "admin") {
		t.Errorf("should contain admin role")
	}
	if !containsString(result, "moderator") {
		t.Errorf("should contain moderator role")
	}

	// Test empty array
	emptyResult := linkedRealmRolesToJSON([]LinkedRealmRole{})
	if emptyResult != "[]" {
		t.Errorf("empty array should return '[]', got '%v'", emptyResult)
	}
}

// TestEscapeString tests the string escaping function
func TestEscapeString(t *testing.T) {
	tt := []struct {
		input    string
		expected string
	}{
		{`hello"world`, `hello\"world`},
		{`hello\world`, `hello\\world`},
		{"hello\nworld", `hello\nworld`},
		{"hello\rworld", `hello\rworld`},
		{"hello\tworld", `hello\tworld`},
		{`complex"test\with\nmultiple\tescapes`, `complex\"test\\with\\nmultiple\\tescapes`},
		{"normal text", "normal text"},
		{"", ""},
	}

	for _, test := range tt {
		result := escapeString(test.input)
		if result != test.expected {
			t.Errorf("escapeString('%v'): expected '%v', got '%v'", test.input, test.expected, result)
		}
	}
}

// TestClaimConstants tests the defined constants
func TestClaimConstants(t *testing.T) {
	// Test maxBlockAge constant
	expectedMaxAge := int64(500)
	if maxBlockAge != expectedMaxAge {
		t.Errorf("expected maxBlockAge to be %v, got %v", expectedMaxAge, maxBlockAge)
	}
}

// Helper function for string contains check (since strings.Contains might not be available)
func containsString(s, substr string) bool {
	return len(s) >= len(substr) && indexOfString(s, substr) >= 0
}

func indexOfString(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
