package user

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"std"
	"strconv"
	"strings"
	"time"

	keyring "gno.land/r/linker000/discord/keyring/v0"
)

const (
	// claimTTL is the maximum duration allowed for a claim to be valid.
	claimTTL = 5 * time.Minute
	//maxClockSkew represents the maximum allowed time skew for claims to exist in the future.
	maxClockSkew = 30 * time.Second
)

// Claim is a struct that represents the contents of a signed claim from the discord bot.
type Claim struct {
	timestamp time.Time
	discordID string
	addr      std.Address
}

// validateEncodedClaim takes a base64 encoded ed25519 based nacl.Sign claim. If the claim is valid
// and all verifications pass, the discord ID and gno address are linked.
// A valid claim must:
// - have a valid signature
// - the payload must be in the format `timestamp,discord_id,gno_address`
// - timestamp must be within the TTL
// - timestamp must not exceed future time clock skew
// - address must match caller
func validateEncodedClaim(encodedClaim string, skipVerifyAddress bool) (*Claim, error) {
	// decode the base64 encoded claim
	decodedClaim, err := base64.RawURLEncoding.DecodeString(encodedClaim)
	if err != nil {
		return nil, err
	}

	// attempt to verify with primary public key, and failover to previous public key
	payload, ok := verifySignature(decodedClaim, keyring.PubKey())
	if !ok {
		payload, ok = verifySignature(decodedClaim, keyring.PreviousPubKey())
		if !ok {
			return nil, errors.New("claim: not a valid signature")
		}
	}

	// create claim from payload
	claim, err := claimFromPayload(string(payload))
	if err != nil {
		return nil, err
	}

	// verify timestamp
	if err := verifyTimestamp(claim.timestamp, time.Now(), claimTTL, maxClockSkew); err != nil {
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

func claimFromPayload(payload string) (*Claim, error) {
	splitPayload := strings.Split(payload, ",")
	if len(splitPayload) != 3 {
		return nil, errors.New("claim: invalid arg length, expecting timestamp,discord_id,gno_addr")
	}
	unixSeconds, err := strconv.ParseInt(splitPayload[0], 10, 64)
	timestamp := time.Unix(unixSeconds, 0)
	if err != nil {
		return nil, errors.New("claim: failed to parse timestamp")
	}

	discordID := splitPayload[1]
	addr := std.Address(splitPayload[2])

	// Validate discord ID
	if err := validateDiscordID(discordID); err != nil {
		return nil, err
	}

	return &Claim{
		timestamp: timestamp,
		discordID: discordID,
		addr:      addr,
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

func verifyTimestamp(claim, evaluated time.Time, ttl, skew time.Duration) error {
	claimAge := evaluated.Sub(claim)
	if claimAge > ttl {
		return errors.New("claim: timestamp exceeds ttl window")
	}
	if claim.After(evaluated.Add(skew)) {
		return errors.New("claim: timestamp exceeds clock skew tolerance")
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
