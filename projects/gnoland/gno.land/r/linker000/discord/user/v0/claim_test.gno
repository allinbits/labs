package user

import (
	"testing"
	"time"

	"gno.land/p/demo/testutils"
)

// TestClaimFromPayload tests parsing payload strings into Claim structs
func TestClaimFromPayload(t *testing.T) {
	tt := []struct {
		payload     string
		shouldFail  bool
		expectedErr string
		description string
	}{
		{
			payload:     "1704067200,123456789012345678,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40",
			shouldFail:  false,
			description: "valid payload should parse successfully",
		},
		{
			payload:     "1704067200,987654321098765432,g1m9pwhrf9tggvz33kq4gv7t9h4rundlj2afcawe",
			shouldFail:  false,
			description: "another valid payload should parse successfully",
		},
		{
			payload:     "invalid_timestamp,123456789012345678,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40",
			shouldFail:  true,
			expectedErr: "claim: failed to parse timestamp",
			description: "invalid timestamp should fail",
		},
		{
			payload:     "1704067200,123456789012345678",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting timestamp,discord_id,gno_addr",
			description: "missing address should fail",
		},
		{
			payload:     "1704067200",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting timestamp,discord_id,gno_addr",
			description: "missing discord ID and address should fail",
		},
		{
			payload:     "",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting timestamp,discord_id,gno_addr",
			description: "empty payload should fail",
		},
		{
			payload:     "1704067200,123456789012345678,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40,extra_field",
			shouldFail:  true,
			expectedErr: "claim: invalid arg length, expecting timestamp,discord_id,gno_addr",
			description: "too many fields should fail",
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

		// Verify parsed claim for successful cases
		if test.payload == "1704067200,123456789012345678,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40" {
			if claim.timestamp.Unix() != 1704067200 {
				t.Errorf("expected timestamp 1704067200, got %v", claim.timestamp.Unix())
			}
			if claim.discordID != "123456789012345678" {
				t.Errorf("expected discord ID '123456789012345678', got '%v'", claim.discordID)
			}
			if string(claim.addr) != "g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40" {
				t.Errorf("expected address 'g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40', got '%v'", string(claim.addr))
			}
		}
	}
}

// TestVerifyTimestamp tests timestamp validation logic
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
			evalTime:    baseTime.Add(1 * time.Minute), // 1 minute after claim
			shouldFail:  false,
			description: "claim within TTL should pass",
		},
		{
			claimTime:   baseTime,
			evalTime:    baseTime.Add(4 * time.Minute), // 4 minutes after claim
			shouldFail:  false,
			description: "claim near TTL limit should pass",
		},
		{
			claimTime:   baseTime,
			evalTime:    baseTime.Add(6 * time.Minute), // 6 minutes after claim (exceeds TTL)
			shouldFail:  true,
			expectedErr: "claim: timestamp exceeds ttl window",
			description: "claim exceeding TTL should fail",
		},
		{
			claimTime:   baseTime.Add(10 * time.Second), // 10 seconds in future
			evalTime:    baseTime,
			shouldFail:  false,
			description: "claim slightly in future (within skew) should pass",
		},
		{
			claimTime:   baseTime.Add(25 * time.Second), // 25 seconds in future
			evalTime:    baseTime,
			shouldFail:  false,
			description: "claim in future within skew tolerance should pass",
		},
		{
			claimTime:   baseTime.Add(1 * time.Minute), // 1 minute in future (exceeds skew)
			evalTime:    baseTime,
			shouldFail:  true,
			expectedErr: "claim: timestamp exceeds clock skew tolerance",
			description: "claim too far in future should fail",
		},
		{
			claimTime:   baseTime,
			evalTime:    baseTime, // exact same time
			shouldFail:  false,
			description: "claim at exact same time should pass",
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

// NOTE: TestVerifyAddress is tested as part of the integration tests in user_test.gno
// where the realm context is properly set up. The verifyAddress function requires
// std.PreviousRealm() which needs a proper realm call stack that's difficult to mock
// in unit tests.

// TestVerifySignature tests signature verification logic
func TestVerifySignature(t *testing.T) {
	// Test 1: Message too short should fail
	shortMessage := make([]byte, 32) // Less than 64 bytes overhead
	pubkey := make([]byte, 32)       // Ed25519 public key is 32 bytes
	
	payload, ok := verifySignature(shortMessage, pubkey)
	if ok {
		t.Errorf("short message should fail verification")
	}
	if payload != nil {
		t.Errorf("failed verification should return nil payload")
	}

	// Test 2: Message with proper length but invalid signature
	longMessage := make([]byte, 100) // 64 bytes overhead + 36 bytes payload
	for i := range longMessage {
		longMessage[i] = byte(i % 256) // Fill with test data
	}
	
	payload, ok = verifySignature(longMessage, pubkey)
	if ok {
		t.Errorf("invalid signature should fail verification")
	}
	if payload != nil {
		t.Errorf("failed verification should return nil payload")
	}

	// Note: We can't test valid signatures in Gno environment since we can't generate them
	// This would require integration tests with actual Discord bot signatures
}

// TestClaimStruct tests the Claim struct and its properties
func TestClaimStruct(t *testing.T) {
	alice := testutils.TestAddress("alice")
	timestamp := time.Unix(1704067200, 0)
	
	claim := &Claim{
		timestamp: timestamp,
		discordID: "123456789012345678",
		addr:      alice,
	}

	// Test field access
	if claim.timestamp != timestamp {
		t.Errorf("expected timestamp %v, got %v", timestamp, claim.timestamp)
	}
	if claim.discordID != "123456789012345678" {
		t.Errorf("expected discord ID '123456789012345678', got '%v'", claim.discordID)
	}
	if claim.addr != alice {
		t.Errorf("expected address %v, got %v", alice, claim.addr)
	}
}

// TestClaimConstants tests the defined constants
func TestClaimConstants(t *testing.T) {
	// Test TTL constant
	expectedTTL := 5 * time.Minute
	if claimTTL != expectedTTL {
		t.Errorf("expected claimTTL to be %v, got %v", expectedTTL, claimTTL)
	}

	// Test clock skew constant
	expectedSkew := 30 * time.Second
	if maxClockSkew != expectedSkew {
		t.Errorf("expected maxClockSkew to be %v, got %v", expectedSkew, maxClockSkew)
	}
}

// TestEdgeCases tests various edge cases
func TestEdgeCases(t *testing.T) {
	// Test 1: Empty discord ID in payload - should now fail due to validation
	_, err := claimFromPayload("1704067200,,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40")
	if err == nil {
		t.Errorf("empty discord ID should fail validation")
	}

	// Test 2: Non-numeric discord ID should fail
	_, err = claimFromPayload("1704067200,invalid_discord_id,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40")
	if err == nil {
		t.Errorf("non-numeric discord ID should fail validation")
	}

	// Test 3: Zero timestamp with valid discord ID
	claim, err := claimFromPayload("0,123456789012345678,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40")
	if err != nil {
		t.Errorf("zero timestamp should be allowed: %v", err)
	}
	if claim.timestamp.Unix() != 0 {
		t.Errorf("expected unix timestamp 0, got %v", claim.timestamp.Unix())
	}

	// Test 4: Very large timestamp
	largeTimestamp := "9999999999" // Year 2286
	claim, err = claimFromPayload(largeTimestamp + ",123456789012345678,g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40")
	if err != nil {
		t.Errorf("large timestamp should be allowed: %v", err)
	}
	if claim.timestamp.Unix() != 9999999999 {
		t.Errorf("expected unix timestamp 9999999999, got %v", claim.timestamp.Unix())
	}

	// Test 5: Discord ID too long should fail
	longDiscordID := "123456789012345678901234567890123" // 33 chars, over limit
	_, err = claimFromPayload("1704067200," + longDiscordID + ",g1jafqkehdf9ezeeu9398xh6lya6qacvjnp5df40")
	if err == nil {
		t.Errorf("discord ID over 32 characters should fail validation")
	}
}