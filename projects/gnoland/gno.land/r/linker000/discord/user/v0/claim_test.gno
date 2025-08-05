package user

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

// TestValidateDiscordID tests Discord ID validation
func TestValidateDiscordID(t *testing.T) {
	tt := []struct {
		discordID   string
		shouldFail  bool
		expectedErr string
		description string
	}{
		{
			discordID:   "123456789012345678",
			shouldFail:  false,
			description: "valid Discord ID should pass",
		},
		{
			discordID:   "987654321098765432",
			shouldFail:  false,
			description: "another valid Discord ID should pass",
		},
		{
			discordID:   "",
			shouldFail:  true,
			expectedErr: "claim: discord ID cannot be empty",
			description: "empty Discord ID should fail",
		},
		{
			discordID:   "12345678901234567890123456789012", // 32 chars
			shouldFail:  false,
			description: "32 character Discord ID should pass",
		},
		{
			discordID:   "123456789012345678901234567890123", // 33 chars
			shouldFail:  true,
			expectedErr: "claim: discord ID too long",
			description: "Discord ID over 32 chars should fail",
		},
		{
			discordID:   "invalid_id_123",
			shouldFail:  true,
			expectedErr: "claim: discord ID must be numeric",
			description: "non-numeric Discord ID should fail",
		},
		{
			discordID:   "12345abc678",
			shouldFail:  true,
			expectedErr: "claim: discord ID must be numeric",
			description: "Discord ID with letters should fail",
		},
	}

	for _, test := range tt {
		err := validateDiscordID(test.discordID)

		if test.shouldFail {
			if err == nil {
				t.Errorf("expected error for discordID='%v', description: %v",
					test.discordID, test.description)
				continue
			}
			if err.Error() != test.expectedErr {
				t.Errorf("expected error '%v', got '%v', description: %v",
					test.expectedErr, err.Error(), test.description)
			}
			continue
		}

		if err != nil {
			t.Errorf("unexpected error for discordID='%v': %v, description: %v",
				test.discordID, err, test.description)
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
	blockHeight := int64(1000)

	claim := &Claim{
		blockHeight: blockHeight,
		discordID:   "123456789012345678",
		addr:        alice,
	}

	// Test field access
	if claim.blockHeight != blockHeight {
		t.Errorf("expected blockHeight %v, got %v", blockHeight, claim.blockHeight)
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
	// Test maxBlockAge constant
	expectedMaxAge := int64(500)
	if maxBlockAge != expectedMaxAge {
		t.Errorf("expected maxBlockAge to be %v, got %v", expectedMaxAge, maxBlockAge)
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
