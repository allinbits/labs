package role

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"net/url"
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
	keyring "gno.land/r/linker000/discord/keyring/v0"
)

const (
	// maxBlockAge is the maximum number of blocks a claim can be old
	maxBlockAge = 500
)

type Claim struct {
	blockHeight      int64
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

// validateLinkClaim validates a claim for linking a realm role to a discord role
func validateLinkClaim(blockHeight int64, discordAccountID, discordGuildID, discordRoleID string,
	addr std.Address, roleName, realmPath, signature string, skipVerifyAddress bool) (*Claim, error) {
	// Check if signature was already used
	if ds.isSignatureUsed(signature) {
		return nil, errors.New("claim: signature already used")
	}

	// URL decode the realmPath and roleName in case they come from URL query parameters
	decodedRealmPath, _ := url.QueryUnescape(realmPath)
	if decodedRealmPath != "" {
		realmPath = decodedRealmPath
	}

	decodedRoleName, _ := url.QueryUnescape(roleName)
	if decodedRoleName != "" {
		roleName = decodedRoleName
	}

	// Decode the signature
	decodedSignature, err := base64.RawURLEncoding.DecodeString(signature)
	if err != nil {
		return nil, errors.New("claim: invalid signature encoding")
	}

	// Reconstruct the payload that was signed
	payload := ufmt.Sprintf("%d,%s,%s,%s,%s,%s,%s", blockHeight, discordAccountID,
		discordGuildID, discordRoleID, addr, roleName, realmPath)

	// Verify signature with primary public key, and failover to previous public key
	verified := ed25519.Verify(keyring.PubKey(), []byte(payload), decodedSignature)
	if !verified {
		verified = ed25519.Verify(keyring.PreviousPubKey(), []byte(payload), decodedSignature)
		if !verified {
			return nil, errors.New("claim: not a valid signature")
		}
	}

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

	// Create claim
	claim := &Claim{
		blockHeight:      blockHeight,
		discordAccountID: discordAccountID,
		discordGuildID:   discordGuildID,
		discordRoleID:    discordRoleID,
		addr:             addr,
		roleName:         roleName,
		realmPath:        realmPath,
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

// validateUnlinkClaim validates a claim for unlinking a realm role from a discord role
func validateUnlinkClaim(blockHeight int64, discordAccountID, discordGuildID string,
	realmPath, roleName, signature string) (*Claim, error) {
	// Check if signature was already used
	if ds.isSignatureUsed(signature) {
		return nil, errors.New("claim: signature already used")
	}

	// URL decode the realmPath and roleName in case they come from URL query parameters
	decodedRealmPath, _ := url.QueryUnescape(realmPath)
	if decodedRealmPath != "" {
		realmPath = decodedRealmPath
	}

	decodedRoleName, _ := url.QueryUnescape(roleName)
	if decodedRoleName != "" {
		roleName = decodedRoleName
	}

	// Decode the signature
	decodedSignature, err := base64.RawURLEncoding.DecodeString(signature)
	if err != nil {
		return nil, errors.New("claim: invalid signature encoding")
	}

	// Reconstruct the payload that was signed (unlink doesn't need role ID or address)
	payload := ufmt.Sprintf("%d,%s,%s,%s,%s", blockHeight, discordAccountID,
		discordGuildID, realmPath, roleName)

	// Verify signature with primary public key, and failover to previous public key
	verified := ed25519.Verify(keyring.PubKey(), []byte(payload), decodedSignature)
	if !verified {
		verified = ed25519.Verify(keyring.PreviousPubKey(), []byte(payload), decodedSignature)
		if !verified {
			return nil, errors.New("claim: not a valid signature")
		}
	}

	// Validate discord IDs
	if err := validateDiscordID(discordAccountID); err != nil {
		return nil, err
	}
	if err := validateDiscordID(discordGuildID); err != nil {
		return nil, err
	}

	// Validate role name and realm path are not empty
	if len(roleName) == 0 {
		return nil, errors.New("claim: role name cannot be empty")
	}
	if len(realmPath) == 0 {
		return nil, errors.New("claim: realm path cannot be empty")
	}

	// Verify block height
	currentHeight := std.ChainHeight()
	if err := verifyBlockHeight(blockHeight, currentHeight); err != nil {
		return nil, err
	}

	// Get the existing claim to return full data
	existingClaim := ds.getByPathRoleGuild(realmPath, roleName, discordGuildID)
	if existingClaim == nil {
		return nil, errors.New("claim: role mapping not found")
	}

	// Return the full claim with all details
	return existingClaim, nil
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
