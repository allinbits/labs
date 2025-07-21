package workflows

import (
	"fmt"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
)

// SyncWorkflowImpl implements the sync workflow
type SyncWorkflowImpl struct {
	gnoClient *contracts.GnoClient
	config    WorkflowConfig
	logger    core.Logger
}

// NewSyncWorkflow creates a new sync workflow
func NewSyncWorkflow(client *contracts.GnoClient, config WorkflowConfig) SyncWorkflow {
	// TODO: Add logger to WorkflowConfig or pass it separately
	// For now, create a default logger
	logger := core.NewSlogLogger(core.ParseLogLevel("info"))
	return &SyncWorkflowImpl{
		gnoClient: client,
		config:    config,
		logger:    logger,
	}
}

// SyncUserRoles synchronizes all roles for a user in a specific realm
func (w *SyncWorkflowImpl) SyncUserRoles(platformID, realmPath, platformGuildID string) ([]core.RoleStatus, error) {
	w.logger.Debug("SyncUserRoles called", "platform_id", platformID, "realm_path", realmPath, "guild_id", platformGuildID)
	
	// Get the user's linked Gno address
	gnoAddress, err := w.gnoClient.GetLinkedAddress(platformID)
	if err != nil {
		w.logger.Error("Failed to get linked address", "error", err, "platform_id", platformID)
		return nil, fmt.Errorf("failed to get linked address: %w", err)
	}
	
	if gnoAddress == "" {
		w.logger.Warn("User has not linked their Gno address", "platform_id", platformID)
		return nil, fmt.Errorf("user has not linked their Gno address")
	}
	
	w.logger.Info("Found linked address", "platform_id", platformID, "gno_address", gnoAddress)
	
	// Get all linked roles for the realm
	linkedRoles, err := w.gnoClient.ListLinkedRoles(realmPath, platformGuildID)
	if err != nil {
		w.logger.Error("Failed to list linked roles", "error", err, "realm_path", realmPath, "guild_id", platformGuildID)
		return nil, fmt.Errorf("failed to list linked roles: %w", err)
	}
	
	w.logger.Info("Found linked roles", "realm_path", realmPath, "guild_id", platformGuildID, "role_count", len(linkedRoles))
	
	// Check membership for each role
	statuses := make([]core.RoleStatus, 0, len(linkedRoles))
	syncTime := time.Now()
	
	for _, roleMapping := range linkedRoles {
		w.logger.Debug("Checking role membership", 
			"realm_path", roleMapping.RealmPath, 
			"role_name", roleMapping.RealmRoleName, 
			"gno_address", gnoAddress)
			
		isMember, err := w.gnoClient.HasRole(roleMapping.RealmPath, roleMapping.RealmRoleName, gnoAddress)
		if err != nil {
			w.logger.Error("Failed to check role membership", 
				"error", err, 
				"realm_path", roleMapping.RealmPath, 
				"role_name", roleMapping.RealmRoleName,
				"gno_address", gnoAddress)
			// Log error but continue with other roles
			continue
		}
		
		w.logger.Info("Role membership check result", 
			"realm_path", roleMapping.RealmPath, 
			"role_name", roleMapping.RealmRoleName, 
			"is_member", isMember)
		
		statuses = append(statuses, core.RoleStatus{
			RoleMapping: *roleMapping,
			IsMember:    isMember,
			SyncedAt:    syncTime,
		})
	}
	
	w.logger.Info("Sync workflow completed", "platform_id", platformID, "statuses_returned", len(statuses))
	return statuses, nil
}