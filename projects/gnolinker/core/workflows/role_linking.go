package workflows

import (
	"encoding/base64"
	"fmt"
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
func (w *RoleLinkingWorkflowImpl) GenerateClaim(organizerID, platformGuildID, platformRoleID, roleName, realmPath string) (*core.Claim, error) {
	// First, get the organizer's linked Gno address
	gnoAddress, err := w.gnoClient.GetLinkedAddress(organizerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get organizer's linked address: %w", err)
	}
	
	if gnoAddress == "" {
		return nil, fmt.Errorf("organizer has not linked their Gno address")
	}
	
	// Check if the organizer has the organizer role in the realm
	hasOrgRole, err := w.gnoClient.HasRole(realmPath, "organizer", gnoAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to check organizer role: %w", err)
	}
	
	if !hasOrgRole {
		return nil, fmt.Errorf("user is not an organizer for realm %s", realmPath)
	}
	
	// Generate the claim
	timestamp := time.Now()
	message := fmt.Sprintf("%v,%v,%v,%v,%v,%v,%v", 
		timestamp.Unix(), organizerID, platformGuildID, platformRoleID, gnoAddress, roleName, realmPath)
	signedMessage := sign.Sign(nil, []byte(message), w.config.SigningKey)
	signature := base64.RawURLEncoding.EncodeToString(signedMessage)
	
	return &core.Claim{
		Type:      core.ClaimTypeRoleLink,
		Data:      message,
		Signature: signature,
		CreatedAt: timestamp,
	}, nil
}

// GenerateUnlinkClaim creates a signed claim for unlinking a realm role from a platform role
func (w *RoleLinkingWorkflowImpl) GenerateUnlinkClaim(organizerID, platformGuildID, platformRoleID, roleName, realmPath string) (*core.Claim, error) {
	// First, get the organizer's linked Gno address
	gnoAddress, err := w.gnoClient.GetLinkedAddress(organizerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get organizer's linked address: %w", err)
	}
	
	if gnoAddress == "" {
		return nil, fmt.Errorf("organizer has not linked their Gno address")
	}
	
	// Check if the organizer has the organizer role in the realm
	hasOrgRole, err := w.gnoClient.HasRole(realmPath, "organizer", gnoAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to check organizer role: %w", err)
	}
	
	if !hasOrgRole {
		return nil, fmt.Errorf("user is not an organizer for realm %s", realmPath)
	}
	
	// Generate the unlink claim
	timestamp := time.Now()
	message := fmt.Sprintf("%v,%v,%v,%v,%v,%v,%v", 
		timestamp.Unix(), organizerID, platformGuildID, platformRoleID, gnoAddress, roleName, realmPath)
	signedMessage := sign.Sign(nil, []byte(message), w.config.SigningKey)
	signature := base64.RawURLEncoding.EncodeToString(signedMessage)
	
	return &core.Claim{
		Type:      core.ClaimTypeRoleUnlink,
		Data:      message,
		Signature: signature,
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

// HasRealmRole checks if an address has a specific role in the realm
func (w *RoleLinkingWorkflowImpl) HasRealmRole(realmPath, roleName, address string) (bool, error) {
	return w.gnoClient.HasRole(realmPath, roleName, address)
}

// GetClaimURL returns the URL where organizers can submit their claim
func (w *RoleLinkingWorkflowImpl) GetClaimURL(claim *core.Claim) string {
	// Format: https://baseurl/r/linker000/discord/role/v0:claim/signature
	return fmt.Sprintf("%s/%s:claim/%s", w.config.BaseURL, w.config.RoleContract, claim.Signature)
}