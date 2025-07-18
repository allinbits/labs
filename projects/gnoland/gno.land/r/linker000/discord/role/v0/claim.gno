package role

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	keyring "gno.land/r/linker000/discord/keyring/v0"
)

const (
	// claimTTL is the maximum duration allowed for a claim to be valid.
	claimTTL = 5 * time.Minute
	//maxClockSkew represents the maximum allowed time skew for claims to exist in the future.
	maxClockSkew = 30 * time.Second
)

type Claim struct {
	timestamp        time.Time
	discordAccountID string
	discordGuildID   string
	discordRoleID    string
	addr             std.Address
	roleName         string
	realmPath        string
}

func (c *Claim) PathRoleGuildKey() string {
	return fmtPathRoleGuildKey(c.realmPath, c.roleName, c.discordGuildID)
}

func (c *Claim) GuildRoleKey() string {
	return fmtGuildRoleKey(c.discordGuildID, c.discordRoleID)
}

func (c *Claim) RoleID() string {
	return c.discordRoleID
}

func (c *Claim) RealmRoleDetails() LinkedRealmRole {
	return LinkedRealmRole{
		RealmPath:      c.realmPath,
		RealmRoleName:  c.roleName,
		DiscordRoleID:  c.discordRoleID,
		DiscordGuildID: c.discordGuildID,
	}
}

func fmtPathGuildKey(realmPath, guildID string) string {
	return ufmt.Sprintf("%s|%s", realmPath, guildID)
}

func fmtPathRoleGuildKey(realmPath, roleName, guildID string) string {
	return ufmt.Sprintf("%s|%s|%s", realmPath, roleName, guildID)
}

func fmtGuildRoleKey(guildID, roleID string) string {
	return ufmt.Sprintf("%s|%s", guildID, roleID)
}

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
	if len(splitPayload) != 7 {
		return nil, errors.New("claim: invalid arg length, expecting 7 values")
	}
	unixSeconds, err := strconv.ParseInt(splitPayload[0], 10, 64)
	timestamp := time.Unix(unixSeconds, 0)
	if err != nil {
		return nil, errors.New("claim: failed to parse timestamp")
	}

	discordAccountID := splitPayload[1]
	discordGuildID := splitPayload[2]
	discordRoleID := splitPayload[3]
	addr := std.Address(splitPayload[4])
	roleName := splitPayload[5]
	realmPath := splitPayload[6]

	// Validate discord IDs
	if err := validateDiscordID(discordAccountID); err != nil {
		return nil, err
	}
	if err := validateDiscordID(discordGuildID); err != nil {
		return nil, err
	}
	if err := validateDiscordID(discordRoleID); err != nil {
		return nil, err
	}

	// Validate role name and realm path are not empty
	if len(roleName) == 0 {
		return nil, errors.New("claim: role name cannot be empty")
	}
	if len(realmPath) == 0 {
		return nil, errors.New("claim: realm path cannot be empty")
	}

	return &Claim{
		timestamp:        timestamp,
		discordAccountID: discordAccountID,
		discordGuildID:   discordGuildID,
		discordRoleID:    discordRoleID,
		addr:             addr,
		roleName:         roleName,
		realmPath:        realmPath,
	}, nil
}

// verifySignature takes a signedMessage and attempts to verify it with any pubkey in the set of pubkeys
// if it is able to verify, it returns the payload and true, otherwise it returns nil and false.
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

type LinkedRealmRole struct {
	RealmPath      string
	RealmRoleName  string
	DiscordRoleID  string
	DiscordGuildID string
}

// Method for a single LinkedRealmRole
func (lrr *LinkedRealmRole) ToJSON() string {
	var sb strings.Builder

	sb.WriteString("{")
	sb.WriteString(ufmt.Sprintf("\"RealmPath\":\"%s\",", escapeString(lrr.RealmPath)))
	sb.WriteString(ufmt.Sprintf("\"RealmRoleName\":\"%s\",", escapeString(lrr.RealmRoleName)))
	sb.WriteString(ufmt.Sprintf("\"DiscordRoleID\":\"%s\",", escapeString(lrr.DiscordRoleID)))
	sb.WriteString(ufmt.Sprintf("\"DiscordGuildID\":\"%s\"", escapeString(lrr.DiscordGuildID)))
	sb.WriteString("}")

	return sb.String()
}

// Function for a slice of LinkedRealmRole
func linkedRealmRolesToJSON(roles []LinkedRealmRole) string {
	var sb strings.Builder

	sb.WriteString("[")

	for i, role := range roles {
		// Use the individual ToJSON method for each role
		sb.WriteString(role.ToJSON())

		// Add comma for all elements except the last one
		if i < len(roles)-1 {
			sb.WriteString(",")
		}
	}

	sb.WriteString("]")
	return sb.String()
}

// Helper function to escape special characters in JSON strings
func escapeString(s string) string {
	s = strings.Replace(s, "\\", "\\\\", -1)
	s = strings.Replace(s, "\"", "\\\"", -1)
	s = strings.Replace(s, "\n", "\\n", -1)
	s = strings.Replace(s, "\r", "\\r", -1)
	s = strings.Replace(s, "\t", "\\t", -1)
	return s
}
