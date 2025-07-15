package discord

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/bwmarrin/discordgo"
)

// DiscordSession interface for testing
type DiscordSession interface {
	GuildRoles(guildID string, options ...discordgo.RequestOption) ([]*discordgo.Role, error)
	GuildRoleCreate(guildID string, data *discordgo.RoleParams, options ...discordgo.RequestOption) (*discordgo.Role, error)
	GuildRoleDelete(guildID, roleID string, options ...discordgo.RequestOption) error
}

// RoleManager handles Discord role creation with distributed locking
type RoleManager struct {
	session     DiscordSession
	lockManager lock.LockManager
	logger      core.Logger
}

// NewRoleManager creates a new role manager
func NewRoleManager(session DiscordSession, lockManager lock.LockManager, logger core.Logger) *RoleManager {
	return &RoleManager{
		session:     session,
		lockManager: lockManager,
		logger:      logger,
	}
}

// GetOrCreateRole safely gets an existing role or creates a new one with distributed locking
func (rm *RoleManager) GetOrCreateRole(guildID, name string, color *int) (*core.PlatformRole, error) {
	// First try to find existing role
	if role, err := rm.getRoleByName(guildID, name); err == nil {
		rm.logger.Debug("Found existing role", "guild_id", guildID, "role_name", name, "role_id", role.ID)
		return &core.PlatformRole{
			ID:   role.ID,
			Name: role.Name,
		}, nil
	}

	// Role doesn't exist, create it with locking if available
	if rm.lockManager != nil {
		return rm.createRoleWithLock(guildID, name, color)
	}

	// Fallback to direct creation if no lock manager
	return rm.createRole(guildID, name, color)
}

// createRoleWithLock creates a role using distributed locking
func (rm *RoleManager) createRoleWithLock(guildID, name string, color *int) (*core.PlatformRole, error) {
	ctx := context.Background()
	lockKey := fmt.Sprintf("role:create:%s:%s", guildID, strings.ReplaceAll(name, " ", "-"))
	
	// Try to acquire lock
	lockAcquired, err := rm.lockManager.AcquireLock(ctx, lockKey, 30*time.Second)
	if err != nil {
		// Failed to get lock, wait and re-check if role was created
		rm.logger.Warn("Failed to acquire lock for role creation, retrying", "guild_id", guildID, "role_name", name, "error", err)
		time.Sleep(2 * time.Second)
		
		// Check if role was created by another instance
		if role, err := rm.getRoleByName(guildID, name); err == nil {
			rm.logger.Info("Role was created by another instance", "guild_id", guildID, "role_name", name, "role_id", role.ID)
			return &core.PlatformRole{
				ID:   role.ID,
				Name: role.Name,
			}, nil
		}
		
		return nil, fmt.Errorf("could not acquire lock for role creation: %w", err)
	}
	
	// Always release lock when done
	defer func() {
		if releaseErr := rm.lockManager.ReleaseLock(ctx, lockAcquired); releaseErr != nil {
			rm.logger.Warn("Failed to release lock", "lock_key", lockKey, "error", releaseErr)
		}
	}()

	// Double-check role doesn't exist (another instance might have created it)
	if role, err := rm.getRoleByName(guildID, name); err == nil {
		rm.logger.Info("Role already exists after acquiring lock", "guild_id", guildID, "role_name", name, "role_id", role.ID)
		return &core.PlatformRole{
			ID:   role.ID,
			Name: role.Name,
		}, nil
	}

	// Safe to create role now
	return rm.createRole(guildID, name, color)
}

// createRole creates a new Discord role
func (rm *RoleManager) createRole(guildID, name string, color *int) (*core.PlatformRole, error) {
	defaultColor := 7506394
	if color == nil {
		color = &defaultColor
	}

	roleData := &discordgo.RoleParams{
		Name:  name,
		Color: color,
	}

	role, err := rm.session.GuildRoleCreate(guildID, roleData)
	if err != nil {
		return nil, fmt.Errorf("failed to create Discord role: %w", err)
	}

	rm.logger.Info("Created new Discord role", "guild_id", guildID, "role_name", role.Name, "role_id", role.ID)
	return &core.PlatformRole{
		ID:   role.ID,
		Name: role.Name,
	}, nil
}

// getRoleByName finds a role by name in the guild
func (rm *RoleManager) getRoleByName(guildID, roleName string) (*discordgo.Role, error) {
	roles, err := rm.session.GuildRoles(guildID)
	if err != nil {
		return nil, fmt.Errorf("failed to get guild roles: %w", err)
	}

	for _, role := range roles {
		if strings.EqualFold(role.Name, roleName) {
			return role, nil
		}
	}

	return nil, fmt.Errorf("role not found: %s", roleName)
}

// DeleteRole safely deletes a role with optional locking
func (rm *RoleManager) DeleteRole(guildID, roleID string) error {
	// For role deletion, we might want locking too, but it's less critical
	// since Discord handles concurrent deletions gracefully
	err := rm.session.GuildRoleDelete(guildID, roleID)
	if err != nil {
		return fmt.Errorf("failed to delete Discord role: %w", err)
	}

	rm.logger.Info("Deleted Discord role", "guild_id", guildID, "role_id", roleID)
	return nil
}