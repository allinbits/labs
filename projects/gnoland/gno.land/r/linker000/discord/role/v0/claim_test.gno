package role

import (
	"testing"
	"time"

	"gno.land/p/demo/testutils"
)

// TestClaimFromPayload tests parsing role claim payload strings into Claim structs
func TestClaimFromPayload(t *testing.T) {
	tt := []struct {
		payload     string
		shouldFail  bool
		expectedErr string
		description string
	}{
		{
			payload:     "1704067200,123456789012345678,987654321098765432,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,admin,gno.land/r/demo/app",
			shouldFail:  false,
			description: "valid role claim payload should parse successfully",
		},
		{
			payload:     "1704067200,555666777888999000,444333222111000999,777888999000111222,g1m9pwhrf9tggvz33kq4gv7t9h4rundlj2afcawe,moderator,gno.land/r/test/realm",
			shouldFail:  false,
			description: "another valid role claim should parse successfully",
		},
		{
			payload:     "invalid_timestamp,123456789012345678,987654321098765432,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,admin,gno.land/r/demo/app",
			shouldFail:  true,
			expectedErr: "claim: failed to parse timestamp",
			description: "invalid timestamp should fail",
		},
		{
			payload:     "1704067200,123456789012345678,987654321098765432,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,admin",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting 7 values",
			description: "missing realm path should fail",
		},
		{
			payload:     "1704067200,123456789012345678,987654321098765432,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting 7 values",
			description: "missing role name and realm path should fail",
		},
		{
			payload:     "",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting 7 values",
			description: "empty payload should fail",
		},
		{
			payload:     "1704067200,123456789012345678,987654321098765432,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,admin,gno.land/r/demo/app,extra",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting 7 values",
			description: "too many fields should fail",
		},
		{
			payload:     "1704067200,,987654321098765432,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,admin,gno.land/r/demo/app",
			shouldFail:  true,
			expectedErr: "claim: discord ID cannot be empty",
			description: "empty discord account ID should fail validation",
		},
		{
			payload:     "1704067200,123456789012345678,,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,admin,gno.land/r/demo/app",
			shouldFail:  true,
			expectedErr: "claim: discord ID cannot be empty",
			description: "empty guild ID should fail validation",
		},
	}

	for _, test := range tt {
		claim, err := claimFromPayload(test.payload)

		if test.shouldFail {
			if err == nil {
				t.Errorf("expected error for payload '%v', description: %v", test.payload, test.description)
				continue
			}
			if err.Error() != test.expectedErr {
				t.Errorf("expected error '%v', got '%v', description: %v", test.expectedErr, err.Error(), test.description)
			}
			continue
		}

		if err != nil {
			t.Errorf("unexpected error for payload '%v': %v, description: %v", test.payload, err, test.description)
			continue
		}

		// Verify parsed claim for first successful case
		if test.payload == "1704067200,123456789012345678,987654321098765432,111222333444555666,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,admin,gno.land/r/demo/app" {
			if claim.timestamp.Unix() != 1704067200 {
				t.Errorf("expected timestamp 1704067200, got %v", claim.timestamp.Unix())
			}
			if claim.discordAccountID != "123456789012345678" {
				t.Errorf("expected discord account ID '123456789012345678', got '%v'", claim.discordAccountID)
			}
			if claim.discordGuildID != "987654321098765432" {
				t.Errorf("expected guild ID '987654321098765432', got '%v'", claim.discordGuildID)
			}
			if claim.discordRoleID != "111222333444555666" {
				t.Errorf("expected role ID '111222333444555666', got '%v'", claim.discordRoleID)
			}
			if string(claim.addr) != "g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40" {
				t.Errorf("expected address 'g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40', got '%v'", string(claim.addr))
			}
			if claim.roleName != "admin" {
				t.Errorf("expected role name 'admin', got '%v'", claim.roleName)
			}
			if claim.realmPath != "gno.land/r/demo/app" {
				t.Errorf("expected realm path 'gno.land/r/demo/app', got '%v'", claim.realmPath)
			}
		}
	}
}

// TestClaimMethods tests the methods on Claim struct
func TestClaimMethods(t *testing.T) {
	claim := &Claim{
		timestamp:        time.Unix(1704067200, 0),
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

// TestVerifyTimestamp tests timestamp validation logic (same as user package)
func TestVerifyTimestamp(t *testing.T) {
	baseTime := time.Unix(1704067200, 0) // 2024-01-01 00:00:00 UTC
	ttl := 5 * time.Minute
	skew := 30 * time.Second

	tt := []struct {
		claimTime   time.Time
		evalTime    time.Time
		shouldFail  bool
		expectedErr string
		description string
	}{
		{
			claimTime:   baseTime,
			evalTime:    baseTime.Add(1 * time.Minute),
			shouldFail:  false,
			description: "claim within TTL should pass",
		},
		{
			claimTime:   baseTime,
			evalTime:    baseTime.Add(6 * time.Minute),
			shouldFail:  true,
			expectedErr: "claim: timestamp exceeds ttl window",
			description: "claim exceeding TTL should fail",
		},
		{
			claimTime:   baseTime.Add(10 * time.Second),
			evalTime:    baseTime,
			shouldFail:  false,
			description: "claim slightly in future (within skew) should pass",
		},
		{
			claimTime:   baseTime.Add(1 * time.Minute),
			evalTime:    baseTime,
			shouldFail:  true,
			expectedErr: "claim: timestamp exceeds clock skew tolerance",
			description: "claim too far in future should fail",
		},
	}

	for _, test := range tt {
		err := verifyTimestamp(test.claimTime, test.evalTime, ttl, skew)

		if test.shouldFail {
			if err == nil {
				t.Errorf("expected error for claimTime=%v, evalTime=%v, description: %v",
					test.claimTime, test.evalTime, test.description)
				continue
			}
			if err.Error() != test.expectedErr {
				t.Errorf("expected error '%v', got '%v', description: %v",
					test.expectedErr, err.Error(), test.description)
			}
			continue
		}

		if err != nil {
			t.Errorf("unexpected error for claimTime=%v, evalTime=%v: %v, description: %v",
				test.claimTime, test.evalTime, err, test.description)
		}
	}
}

// TestVerifySignature tests signature verification logic (same as user package)
func TestVerifySignature(t *testing.T) {
	// Test 1: Message too short should fail
	shortMessage := make([]byte, 32)
	pubkey := make([]byte, 32)

	payload, ok := verifySignature(shortMessage, pubkey)
	if ok {
		t.Errorf("short message should fail verification")
	}
	if payload != nil {
		t.Errorf("failed verification should return nil payload")
	}

	// Test 2: Message with proper length but invalid signature
	longMessage := make([]byte, 100)
	for i := range longMessage {
		longMessage[i] = byte(i % 256)
	}

	payload, ok = verifySignature(longMessage, pubkey)
	if ok {
		t.Errorf("invalid signature should fail verification")
	}
	if payload != nil {
		t.Errorf("failed verification should return nil payload")
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
	expectedTTL := 5 * time.Minute
	if claimTTL != expectedTTL {
		t.Errorf("expected claimTTL to be %v, got %v", expectedTTL, claimTTL)
	}

	expectedSkew := 30 * time.Second
	if maxClockSkew != expectedSkew {
		t.Errorf("expected maxClockSkew to be %v, got %v", expectedSkew, maxClockSkew)
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
