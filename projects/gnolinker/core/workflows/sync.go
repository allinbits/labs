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
}

// NewSyncWorkflow creates a new sync workflow
func NewSyncWorkflow(client *contracts.GnoClient, config WorkflowConfig) SyncWorkflow {
	return &SyncWorkflowImpl{
		gnoClient: client,
		config:    config,
	}
}

// SyncUserRoles synchronizes all roles for a user in a specific realm
func (w *SyncWorkflowImpl) SyncUserRoles(platformID, realmPath, platformGuildID string) ([]core.RoleStatus, error) {
	// Get the user's linked Gno address
	gnoAddress, err := w.gnoClient.GetLinkedAddress(platformID)
	if err != nil {
		return nil, fmt.Errorf("failed to get linked address: %w", err)
	}
	
	if gnoAddress == "" {
		return nil, fmt.Errorf("user has not linked their Gno address")
	}
	
	// Get all linked roles for the realm
	linkedRoles, err := w.gnoClient.ListLinkedRoles(realmPath, platformGuildID)
	if err != nil {
		return nil, fmt.Errorf("failed to list linked roles: %w", err)
	}
	
	// Check membership for each role
	statuses := make([]core.RoleStatus, 0, len(linkedRoles))
	syncTime := time.Now()
	
	for _, roleMapping := range linkedRoles {
		isMember, err := w.gnoClient.HasRole(roleMapping.RealmPath, roleMapping.RealmRoleName, gnoAddress)
		if err != nil {
			// Log error but continue with other roles
			continue
		}
		
		statuses = append(statuses, core.RoleStatus{
			RoleMapping: *roleMapping,
			IsMember:    isMember,
			SyncedAt:    syncTime,
		})
	}
	
	return statuses, nil
}