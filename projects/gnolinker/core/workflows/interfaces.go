package workflows

import (
	"github.com/allinbits/labs/projects/gnolinker/core"
)

// UserLinkingWorkflow handles the user address linking flow
type UserLinkingWorkflow interface {
	// GenerateClaim creates a signed claim for linking a platform user to a Gno address
	GenerateClaim(platformID, gnoAddress string) (*core.Claim, error)
	
	// GetLinkedAddress retrieves the Gno address linked to a platform user
	GetLinkedAddress(platformID string) (string, error)
	
	// GetClaimURL returns the URL where users can submit their claim
	GetClaimURL(claim *core.Claim) string
}

// RoleLinkingWorkflow handles the role mapping flow for organizers
type RoleLinkingWorkflow interface {
	// GenerateClaim creates a signed claim for linking a realm role to a platform role
	GenerateClaim(organizerID, platformGuildID, platformRoleID, roleName, realmPath string) (*core.Claim, error)
	
	// GetLinkedRole retrieves the role mapping for a specific realm role
	GetLinkedRole(realmPath, roleName, platformGuildID string) (*core.RoleMapping, error)
	
	// ListLinkedRoles retrieves all role mappings for a realm
	ListLinkedRoles(realmPath, platformGuildID string) ([]*core.RoleMapping, error)
	
	// GetClaimURL returns the URL where organizers can submit their claim
	GetClaimURL(claim *core.Claim) string
}

// SyncWorkflow handles role membership synchronization
type SyncWorkflow interface {
	// SyncUserRoles synchronizes all roles for a user in a specific realm
	SyncUserRoles(platformID, realmPath, platformGuildID string) ([]core.RoleStatus, error)
}

// WorkflowConfig contains configuration for all workflows
type WorkflowConfig struct {
	// SigningKey is the bot's private key for signing claims
	SigningKey *[64]byte
	
	// BaseURL is the base URL for claim submission (e.g., "https://labsnet.fly.dev")
	BaseURL string
	
	// UserContract is the path to the user linking contract
	UserContract string
	
	// RoleContract is the path to the role linking contract
	RoleContract string
}