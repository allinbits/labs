package keyring

import (
	"encoding/hex"
	"std"

	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
)

const (
	invalidKeyLength string = "rotation error: invalid key length"
	invalidHexEncoding string = "rotation error: invalid hex encoding"
	notAuthorizedMsg string = "rotation error: not authorized"
)

var (
	current  []byte
	previous []byte

	// linker000 address
	owner = ownable.NewWithAddress("g1aa5umzchlwqxtdfh58exmydmzsgpzcg3u9egcp")
	// n2p5 address
	backup = ownable.NewWithAddress("g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")
)

func init() {
	// initial pubkey
	pkHex := "159feebfac754a23d1f04a88c3e21ebc7aa55afe8e8262d773a75a98c62dfb62"
	current, _ = hex.DecodeString(pkHex)
	previous = current
}

// PubKey returns a byte slice of the current pubkey
func PubKey() []byte {
	return current
}

// PreviousPubKey returns a byte slice of the previous pubkey
func PreviousPubKey() []byte {
	return previous
}

// Rotate takes a hex encoded ed25519 public key and rotates the current key to previous
// and the new key becomes the current key. The caller must be either the owner or backup
// address specified in the contract. The hexKey must be exactly 64 characters long, and
// the hexKey must be valid hex encoding, otherwise, rotate panics.
func Rotate(hexKey string) {
	crossing()
	assertIsAuthorized()
	if len(hexKey) != 64 {
		panic(invalidKeyLength)
	}
	key, err := hex.DecodeString(hexKey)
	if err != nil {
		panic(invalidHexEncoding)
	}
	previous = current
	current = key
}

// assertIsAuthorized checks that the caller is either the owner or the backup user.
func assertIsAuthorized() {
	caller := std.PreviousRealm().Address()
	if !(caller == owner.Owner() || caller == backup.Owner()) {
		panic(notAuthorizedMsg)
	}
}

// Render displays basic information about the contract, including the hex encoded
// current and previous pubkey.
func Render(_ string) string {
	c := hex.EncodeToString(current)
	p := hex.EncodeToString(previous)

	return ufmt.Sprintf(`
# Discord Bot Keyring

Discord Bot maintains an ed25519 private key for signing claims. This contract keeps
track of the current active public key as well as the previous public key so that change
management processes on the discord bot can happen smoothly.

## Current Pubkey: 

%v

## Previous Pubkey: 

%v
`, c, p)

}
