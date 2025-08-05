package workflows

import (
	"encoding/base64"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
	"golang.org/x/crypto/nacl/sign"
)

// RoleLinkingWorkflowImpl implements the role linking workflow
type RoleLinkingWorkflowImpl struct {
	gnoClient *contracts.GnoClient
	config    WorkflowConfig
}

// NewRoleLinkingWorkflow creates a new role linking workflow
func NewRoleLinkingWorkflow(client *contracts.GnoClient, config WorkflowConfig) RoleLinkingWorkflow {
	return &RoleLinkingWorkflowImpl{
		gnoClient: client,
		config:    config,
	}
}

// GenerateClaim creates a signed claim for linking a realm role to a platform role
func (w *RoleLinkingWorkflowImpl) GenerateClaim(userID, platformGuildID, platformRoleID, roleName, realmPath string) (*core.Claim, error) {
	// Get the user's linked Gno address for the claim
	gnoAddress, err := w.gnoClient.GetLinkedAddress(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get linked address: %w", err)
	}

	if gnoAddress == "" {
		return nil, fmt.Errorf("user has not linked their Gno address")
	}

	// Get current block height
	blockHeight, err := w.gnoClient.GetCurrentBlockHeight()
	if err != nil {
		return nil, fmt.Errorf("failed to get current block height: %w", err)
	}

	// Generate the claim
	timestamp := time.Now()
	message := fmt.Sprintf("%d,%s,%s,%s,%s,%s,%s",
		blockHeight, userID, platformGuildID, platformRoleID, gnoAddress, roleName, realmPath)
	signature := sign.Sign(nil, []byte(message), w.config.SigningKey)[:64] // Only the signature part
	signatureEncoded := base64.RawURLEncoding.EncodeToString(signature)

	return &core.Claim{
		Type:      core.ClaimTypeRoleLink,
		Data:      message,
		Signature: signatureEncoded,
		CreatedAt: timestamp,
	}, nil
}

// GenerateUnlinkClaim creates a signed claim for unlinking a realm role from a platform role
func (w *RoleLinkingWorkflowImpl) GenerateUnlinkClaim(userID, platformGuildID, platformRoleID, roleName, realmPath string) (*core.Claim, error) {
	// Get current block height
	blockHeight, err := w.gnoClient.GetCurrentBlockHeight()
	if err != nil {
		return nil, fmt.Errorf("failed to get current block height: %w", err)
	}

	// Generate the unlink claim (doesn't need role ID or address)
	timestamp := time.Now()
	message := fmt.Sprintf("%d,%s,%s,%s,%s",
		blockHeight, userID, platformGuildID, realmPath, roleName)
	signature := sign.Sign(nil, []byte(message), w.config.SigningKey)[:64] // Only the signature part
	signatureEncoded := base64.RawURLEncoding.EncodeToString(signature)

	return &core.Claim{
		Type:      core.ClaimTypeRoleUnlink,
		Data:      message,
		Signature: signatureEncoded,
		CreatedAt: timestamp,
	}, nil
}

// GetLinkedRole retrieves the role mapping for a specific realm role
func (w *RoleLinkingWorkflowImpl) GetLinkedRole(realmPath, roleName, platformGuildID string) (*core.RoleMapping, error) {
	return w.gnoClient.GetLinkedRole(realmPath, roleName, platformGuildID)
}

// ListLinkedRoles retrieves all role mappings for a realm
func (w *RoleLinkingWorkflowImpl) ListLinkedRoles(realmPath, platformGuildID string) ([]*core.RoleMapping, error) {
	return w.gnoClient.ListLinkedRoles(realmPath, platformGuildID)
}

// ListAllRolesByGuild retrieves all role mappings for a guild across all realms
func (w *RoleLinkingWorkflowImpl) ListAllRolesByGuild(platformGuildID string) ([]*core.RoleMapping, error) {
	return w.gnoClient.ListAllRolesByGuild(platformGuildID)
}

// HasRealmRole checks if an address has a specific role in the realm
func (w *RoleLinkingWorkflowImpl) HasRealmRole(realmPath, roleName, address string) (bool, error) {
	return w.gnoClient.HasRole(realmPath, roleName, address)
}

// GetClaimURL returns the URL where admins can submit their claim
func (w *RoleLinkingWorkflowImpl) GetClaimURL(claim *core.Claim) string {
	// Parse the claim data to extract fields
	parts := strings.Split(claim.Data, ",")

	if claim.Type == core.ClaimTypeRoleLink {
		// Link claim format: blockHeight,discordAccountID,discordGuildID,discordRoleID,address,roleName,realmPath
		if len(parts) < 7 {
			return "" // Invalid claim data
		}

		// Build URL with query parameters for link
		params := url.Values{}
		params.Add("blockHeight", parts[0])
		params.Add("discordAccountID", parts[1])
		params.Add("discordGuildID", parts[2])
		params.Add("discordRoleID", parts[3])
		params.Add("address", parts[4])
		params.Add("roleName", parts[5])
		params.Add("realmPath", parts[6])
		params.Add("signature", claim.Signature)

		return fmt.Sprintf("%s/%s:link?%s", w.config.BaseURL, w.config.RoleContract, params.Encode())
	} else {
		// Unlink claim format: blockHeight,discordAccountID,discordGuildID,realmPath,roleName
		if len(parts) < 5 {
			return "" // Invalid claim data
		}

		// Build URL with query parameters for unlink
		params := url.Values{}
		params.Add("blockHeight", parts[0])
		params.Add("discordAccountID", parts[1])
		params.Add("discordGuildID", parts[2])
		params.Add("realmPath", parts[3])
		params.Add("roleName", parts[4])
		params.Add("signature", claim.Signature)

		return fmt.Sprintf("%s/%s:unlink?%s", w.config.BaseURL, w.config.RoleContract, params.Encode())
	}
}
