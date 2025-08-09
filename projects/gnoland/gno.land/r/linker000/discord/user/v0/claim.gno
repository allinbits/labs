package user

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"std"

	"gno.land/p/demo/ufmt"

	keyring "gno.land/r/linker000/discord/keyring/v0"
)

const (
	// maxBlockAge is the maximum number of blocks a claim can be old
	maxBlockAge = 500
)

// Claim is a struct that represents the contents of a signed claim from the discord bot.
type Claim struct {
	blockHeight int64
	discordID   string
	addr        std.Address
}

// validateLinkClaim validates a claim for linking a discord ID to a gno address
// A valid claim must:
// - have a valid signature for the payload `block_height,discord_id,gno_address`
// - signature must not have been used before
// - block height must not be in the future
// - block height must not be too old (maxBlockAge)
// - address must match caller (unless skipVerifyAddress is true)
func validateLinkClaim(blockHeight int64, discordID string, addr std.Address, signature string, skipVerifyAddress bool) (*Claim, error) {
	// Check if signature was already used
	if ds.isSignatureUsed(signature) {
		return nil, errors.New("claim: signature already used")
	}

	// Decode the signature
	decodedSignature, err := base64.RawURLEncoding.DecodeString(signature)
	if err != nil {
		return nil, errors.New("claim: invalid signature encoding")
	}

	// Reconstruct the payload that was signed
	payload := ufmt.Sprintf("%d,%s,%s", blockHeight, discordID, addr)

	// Verify signature with primary public key, and failover to previous public key
	verified := ed25519.Verify(keyring.PubKey(), []byte(payload), decodedSignature)
	if !verified {
		verified = ed25519.Verify(keyring.PreviousPubKey(), []byte(payload), decodedSignature)
		if !verified {
			return nil, errors.New("claim: not a valid signature")
		}
	}

	// Validate discord ID
	if err := validateDiscordID(discordID); err != nil {
		return nil, err
	}

	// Create claim
	claim := &Claim{
		blockHeight: blockHeight,
		discordID:   discordID,
		addr:        addr,
	}

	// Verify block height
	currentHeight := std.ChainHeight()
	if err := verifyBlockHeight(claim.blockHeight, currentHeight); err != nil {
		return nil, err
	}

	if !skipVerifyAddress {
		// verify address
		if err := verifyAddress(claim.addr); err != nil {
			return nil, err
		}
	}

	return claim, nil
}

// validateUnlinkClaim validates a claim for unlinking a discord ID
// This is used when someone wants to unlink but might not control the gno address anymore
// A valid claim must:
// - have a valid signature for the payload `block_height,discord_id`
// - signature must not have been used before
// - block height must not be in the future
// - block height must not be too old (maxBlockAge)
// - discord ID must be currently linked
func validateUnlinkClaim(blockHeight int64, discordID string, signature string) (*Claim, error) {
	// Check if signature was already used
	if ds.isSignatureUsed(signature) {
		return nil, errors.New("claim: signature already used")
	}

	// Decode the signature
	decodedSignature, err := base64.RawURLEncoding.DecodeString(signature)
	if err != nil {
		return nil, errors.New("claim: invalid signature encoding")
	}

	// Reconstruct the payload that was signed (just block_height and discord_id for unlink)
	payload := ufmt.Sprintf("%d,%s", blockHeight, discordID)

	// Verify signature with primary public key, and failover to previous public key
	verified := ed25519.Verify(keyring.PubKey(), []byte(payload), decodedSignature)
	if !verified {
		verified = ed25519.Verify(keyring.PreviousPubKey(), []byte(payload), decodedSignature)
		if !verified {
			return nil, errors.New("claim: not a valid signature")
		}
	}

	// Validate discord ID
	if err := validateDiscordID(discordID); err != nil {
		return nil, err
	}

	// Verify block height
	currentHeight := std.ChainHeight()
	if err := verifyBlockHeight(blockHeight, currentHeight); err != nil {
		return nil, err
	}

	// Get the linked claim to return the full claim data
	existingClaim := ds.getByDiscordID(discordID)
	if existingClaim == nil {
		return nil, errors.New("claim: discord ID is not linked")
	}

	// Return the existing claim with updated block height for tracking
	return &Claim{
		blockHeight: blockHeight,
		discordID:   existingClaim.discordID,
		addr:        existingClaim.addr,
	}, nil
}

func verifyAddress(addr std.Address) error {
	caller := std.PreviousRealm().Address()
	if addr != caller {
		return errors.New("claim: address does not match caller")
	}
	return nil
}

// validateDiscordID validates that the Discord ID is reasonable
func validateDiscordID(discordID string) error {
	if len(discordID) == 0 {
		return errors.New("claim: discord ID cannot be empty")
	}
	if len(discordID) > 32 {
		return errors.New("claim: discord ID too long")
	}
	// Discord IDs should be numeric (snowflake format)
	for _, char := range discordID {
		if char < '0' || char > '9' {
			return errors.New("claim: discord ID must be numeric")
		}
	}
	return nil
}

func verifyBlockHeight(claimHeight, currentHeight int64) error {
	// Check if claim is from the future
	if claimHeight > currentHeight {
		return errors.New(ufmt.Sprintf("claim: block height is in the future (claim: %d, current: %d)",
			claimHeight, currentHeight))
	}

	// Check if claim is too old
	age := currentHeight - claimHeight
	if age > maxBlockAge {
		return errors.New(ufmt.Sprintf("claim: block height too old (age: %d blocks, max: %d blocks, claim: %d, current: %d)",
			age, maxBlockAge, claimHeight, currentHeight))
	}

	return nil
}

// verifySignature takes a signedMessage and a pubkey and attempts to verify.
// If it is able to verify, it returns the payload and true, otherwise it
// returns nil and false.
func verifySignature(signedMessage, pubkey []byte) ([]byte, bool) {
	overhead := 64
	if len(signedMessage) < overhead {
		return nil, false
	}
	if ed25519.Verify(pubkey, signedMessage[overhead:], signedMessage[:overhead]) {
		out := make([]byte, len(signedMessage)-overhead)
		copy(out, signedMessage[overhead:])
		return out, true
	}
	return nil, false
}
