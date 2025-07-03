package keyring

import (
	"encoding/hex"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
)

func TestPubkey(t *testing.T) {
	initialKey := "159feebfac754a23d1f04a88c3e21ebc7aa55afe8e8262d773a75a98c62dfb62"
	pk := hex.EncodeToString(PubKey())
	if pk != initialKey {
		t.Error("initial key does not equal pubkey")
	}
}

func TestPreviousPubKey(t *testing.T) {
	initialKey := "159feebfac754a23d1f04a88c3e21ebc7aa55afe8e8262d773a75a98c62dfb62"
	pk := hex.EncodeToString(PreviousPubKey())
	if pk != initialKey {
		t.Error("initial previous key does not equal pubkey")
	}
}

func TestRotate(t *testing.T) {
	k0 := "159feebfac754a23d1f04a88c3e21ebc7aa55afe8e8262d773a75a98c62dfb62"
	k1 := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	k2 := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	invalidHex := "$$$$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

	owner := std.Address("g1aa5umzchlwqxtdfh58exmydmzsgpzcg3u9egcp")
	backup := std.Address("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")
	alice := testutils.TestAddress("alice")

	tt := []struct {
		caller           std.Address
		key              string
		expectedKey      string
		expectedPrevious string
		shouldFail       bool
		reviveMsg        string
		description      string
	}{
		{
			caller:           owner,
			key:              "",
			expectedKey:      k0,
			expectedPrevious: k0,
			description:      "no change, original keys should be in place",
		},
		{
			caller:           owner,
			key:              k1,
			expectedKey:      k1,
			expectedPrevious: k0,
			description:      "rotate primary key",
		},
		{
			caller:           owner,
			key:              k2,
			expectedKey:      k2,
			expectedPrevious: k1,
			description:      "rotate primary key again",
		},
		{
			caller:           backup,
			key:              k0,
			expectedKey:      k0,
			expectedPrevious: k2,
			description:      "backup owner should be allowed to rotate the key",
		},
		{
			caller:      alice,
			key:         k0,
			shouldFail:  true,
			reviveMsg:   notAuthorizedMsg,
			description: "alice should not be authorized to rotate",
		},
		{
			caller:      owner,
			key:         "tooshort",
			shouldFail:  true,
			reviveMsg:   invalidKeyLength,
			description: "invalid key length that is too short should be rejected",
		},
		{
			caller:      owner,
			key:         k0 + "toolong",
			shouldFail:  true,
			reviveMsg:   invalidKeyLength,
			description: "invalid key length that is too long should be rejected",
		},
		{
			caller:      owner,
			key:         invalidHex,
			shouldFail:  true,
			reviveMsg:   invalidHexEncoding,
			description: "invalid hex encoded string",
		},
	}

	for _, test := range tt {
		testing.SetOriginCaller(test.caller)
		if test.shouldFail {
			r := revive(func() {
				Rotate(cross, test.key)
			})
			if r != test.reviveMsg {
				t.Errorf("expected: %v, got: %v, description: %v\n", test.reviveMsg, r, test.description)
			}
			continue
		}
		if test.key != "" {
			Rotate(cross, test.key)
		}
		pubk := hex.EncodeToString(PubKey())
		if test.expectedKey != pubk {
			t.Errorf("expected: %v, got: %v, description %v\n", test.expectedKey, pubk, test.description)
		}
		prev := hex.EncodeToString(PreviousPubKey())
		if test.expectedPrevious != prev {
			t.Errorf("expected: %v, got: %v, description %v\n", test.expectedKey, prev, test.description)
		}
	}
}
