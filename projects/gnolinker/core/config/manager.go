package config

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
	"github.com/bwmarrin/discordgo"
)

// DiscordSession interface for ConfigManager testing
type DiscordSession interface {
	GuildRoles(guildID string, options ...discordgo.RequestOption) ([]*discordgo.Role, error)
	GuildRoleCreate(guildID string, data *discordgo.RoleParams, options ...discordgo.RequestOption) (*discordgo.Role, error)
}

// ConfigManager handles guild configuration management with smart role detection
type ConfigManager struct {
	store                 storage.ConfigStore
	storageConfig         *StorageConfig
	lockManager           lock.LockManager
	logger                core.Logger
	lockFailureRetryDelay time.Duration
}

// NewConfigManager creates a new configuration manager
func NewConfigManager(store storage.ConfigStore, storageConfig *StorageConfig, lockManager lock.LockManager, logger core.Logger) *ConfigManager {
	return &ConfigManager{
		store:                 store,
		storageConfig:         storageConfig,
		lockManager:           lockManager,
		logger:                logger,
		lockFailureRetryDelay: 2 * time.Second, // Default to 2 seconds
	}
}

// NewConfigManagerWithConfig creates a new configuration manager with custom configuration
func NewConfigManagerWithConfig(store storage.ConfigStore, storageConfig *StorageConfig, lockManager lock.LockManager, logger core.Logger, lockFailureRetryDelay time.Duration) *ConfigManager {
	return &ConfigManager{
		store:                 store,
		storageConfig:         storageConfig,
		lockManager:           lockManager,
		logger:                logger,
		lockFailureRetryDelay: lockFailureRetryDelay,
	}
}

// EnsureGuildConfig ensures a guild has a valid configuration, creating one if needed
func (m *ConfigManager) EnsureGuildConfig(session DiscordSession, guildID string) (*storage.GuildConfig, error) {
	// Try to get existing config
	config, err := m.store.Get(guildID)
	if err == nil {
		// Validate existing config and repair if needed
		return m.validateAndRepairConfig(session, config)
	}

	// Config doesn't exist, create a new one
	m.logger.Info("Creating new guild configuration", "guild_id", guildID)
	config = storage.NewGuildConfig(guildID)

	// Auto-detect and set up roles
	if err := m.setupGuildRoles(session, config); err != nil {
		m.logger.Error("Failed to setup guild roles", "error", err, "guild_id", guildID)
		// Continue with empty role config rather than failing completely
	}

	// Save the new config
	if err := m.store.Set(guildID, config); err != nil {
		return nil, fmt.Errorf("failed to save new guild config: %w", err)
	}

	m.logger.Info("Successfully created guild configuration", "guild_id", guildID)
	return config, nil
}

// GetGuildConfig retrieves a guild configuration
func (m *ConfigManager) GetGuildConfig(guildID string) (*storage.GuildConfig, error) {
	return m.store.Get(guildID)
}

// GetStorageConfig returns the storage configuration
func (m *ConfigManager) GetStorageConfig() *StorageConfig {
	return m.storageConfig
}

// GetLockManager returns the lock manager
func (m *ConfigManager) GetLockManager() lock.LockManager {
	return m.lockManager
}

// UpdateGuildConfig updates a guild configuration
func (m *ConfigManager) UpdateGuildConfig(guildID string, config *storage.GuildConfig) error {
	return m.store.Set(guildID, config)
}

// DeleteGuildConfig removes a guild configuration
func (m *ConfigManager) DeleteGuildConfig(guildID string) error {
	return m.store.Delete(guildID)
}

// validateAndRepairConfig validates an existing config and repairs issues
func (m *ConfigManager) validateAndRepairConfig(session DiscordSession, config *storage.GuildConfig) (*storage.GuildConfig, error) {
	needsUpdate := false

	// Validate admin role
	if config.AdminRoleID != "" {
		if !m.roleExists(session, config.GuildID, config.AdminRoleID) {
			m.logger.Warn("Admin role no longer exists, clearing", "guild_id", config.GuildID, "role_id", config.AdminRoleID)
			config.AdminRoleID = ""
			needsUpdate = true
		}
	}

	// Validate verified role
	if config.VerifiedRoleID != "" {
		if !m.roleExists(session, config.GuildID, config.VerifiedRoleID) {
			m.logger.Warn("Verified role no longer exists, attempting to recreate", "guild_id", config.GuildID, "role_id", config.VerifiedRoleID)
			if err := m.ensureVerifiedRole(session, config); err != nil {
				m.logger.Error("Failed to recreate verified role", "error", err, "guild_id", config.GuildID)
				config.VerifiedRoleID = ""
			}
			needsUpdate = true
		}
	}

	// If no admin role is set, try to detect one
	if config.AdminRoleID == "" {
		if adminRoleID := m.detectAdminRole(session, config.GuildID); adminRoleID != "" {
			config.AdminRoleID = adminRoleID
			needsUpdate = true
		}
	}

	// If no verified role is set and auto-create is enabled, create one
	if config.VerifiedRoleID == "" && m.storageConfig.AutoCreateRoles {
		if err := m.ensureVerifiedRole(session, config); err == nil {
			needsUpdate = true
		}
	}

	// Save if updated
	if needsUpdate {
		if err := m.store.Set(config.GuildID, config); err != nil {
			m.logger.Error("Failed to save repaired config", "error", err, "guild_id", config.GuildID)
		}
	}

	return config, nil
}

// setupGuildRoles sets up roles for a new guild configuration
func (m *ConfigManager) setupGuildRoles(session DiscordSession, config *storage.GuildConfig) error {
	// Try to detect admin role
	if adminRoleID := m.detectAdminRole(session, config.GuildID); adminRoleID != "" {
		config.AdminRoleID = adminRoleID
		m.logger.Info("Detected admin role", "guild_id", config.GuildID, "role_id", adminRoleID)
	}

	// Create or find verified role if auto-create is enabled
	if m.storageConfig.AutoCreateRoles {
		if err := m.ensureVerifiedRole(session, config); err != nil {
			return fmt.Errorf("failed to ensure verified role: %w", err)
		}
	}

	return nil
}

// detectAdminRole attempts to find a suitable admin role in the guild
func (m *ConfigManager) detectAdminRole(session DiscordSession, guildID string) string {
	roles, err := session.GuildRoles(guildID)
	if err != nil {
		m.logger.Error("Failed to get guild roles for admin detection", "error", err, "guild_id", guildID)
		return ""
	}

	// Look for roles with Administrator permission
	for _, role := range roles {
		if role.Permissions&discordgo.PermissionAdministrator != 0 {
			// Skip @everyone role and bot roles
			if role.Name != "@everyone" && !role.Managed {
				m.logger.Info("Found potential admin role", "guild_id", guildID, "role_name", role.Name, "role_id", role.ID)
				return role.ID
			}
		}
	}

	// Look for roles with common admin names
	adminRoleNames := []string{"admin", "administrator", "mod", "moderator", "staff", "gno admin", "gnolinker admin"}
	for _, role := range roles {
		// Skip @everyone role and bot roles
		if role.Name != "@everyone" && !role.Managed {
			roleName := strings.ToLower(role.Name)
			for _, adminName := range adminRoleNames {
				if strings.Contains(roleName, adminName) {
					m.logger.Info("Found admin role by name", "guild_id", guildID, "role_name", role.Name, "role_id", role.ID)
					return role.ID
				}
			}
		}
	}

	return ""
}

// ensureVerifiedRole creates or finds the verified role with distributed locking
func (m *ConfigManager) ensureVerifiedRole(session DiscordSession, config *storage.GuildConfig) error {
	// First try to find existing role by name
	if roleID := m.findRoleByName(session, config.GuildID, m.storageConfig.DefaultVerifiedRoleName); roleID != "" {
		config.VerifiedRoleID = roleID
		m.logger.Info("Found existing verified role", "guild_id", config.GuildID, "role_name", m.storageConfig.DefaultVerifiedRoleName, "role_id", roleID)
		return nil
	}

	// Use distributed lock for role creation to prevent race conditions
	if m.lockManager != nil {
		return m.ensureVerifiedRoleWithLock(session, config)
	}

	// Fallback to direct creation if no lock manager
	return m.createVerifiedRole(session, config)
}

// ensureVerifiedRoleWithLock creates a verified role using distributed locking
func (m *ConfigManager) ensureVerifiedRoleWithLock(session DiscordSession, config *storage.GuildConfig) error {
	ctx := context.Background()
	lockKey := fmt.Sprintf("role:create:%s:verified", config.GuildID)
	
	// Try to acquire lock
	lockAcquired, err := m.lockManager.AcquireLock(ctx, lockKey, 30*time.Second)
	if err != nil {
		// Failed to get lock, wait and re-check if role was created
		m.logger.Warn("Failed to acquire lock for role creation, retrying", "guild_id", config.GuildID, "error", err)
		time.Sleep(m.lockFailureRetryDelay)
		
		// Check if role was created by another instance
		if roleID := m.findRoleByName(session, config.GuildID, m.storageConfig.DefaultVerifiedRoleName); roleID != "" {
			config.VerifiedRoleID = roleID
			m.logger.Info("Role was created by another instance", "guild_id", config.GuildID, "role_id", roleID)
			return nil
		}
		
		return fmt.Errorf("could not acquire lock for role creation: %w", err)
	}
	
	// Always release lock when done
	defer func() {
		if releaseErr := m.lockManager.ReleaseLock(ctx, lockAcquired); releaseErr != nil {
			m.logger.Warn("Failed to release lock", "lock_key", lockKey, "error", releaseErr)
		}
	}()

	// Double-check role doesn't exist (another instance might have created it)
	if roleID := m.findRoleByName(session, config.GuildID, m.storageConfig.DefaultVerifiedRoleName); roleID != "" {
		config.VerifiedRoleID = roleID
		m.logger.Info("Role already exists after acquiring lock", "guild_id", config.GuildID, "role_id", roleID)
		return nil
	}

	// Safe to create role now
	return m.createVerifiedRole(session, config)
}

// createVerifiedRole creates a new verified role
func (m *ConfigManager) createVerifiedRole(session DiscordSession, config *storage.GuildConfig) error {
	roleData := &discordgo.RoleParams{
		Name:  m.storageConfig.DefaultVerifiedRoleName,
		Color: &[]int{0x00ff00}[0], // Green color
	}

	role, err := session.GuildRoleCreate(config.GuildID, roleData)
	if err != nil {
		return fmt.Errorf("failed to create verified role: %w", err)
	}

	config.VerifiedRoleID = role.ID
	m.logger.Info("Created new verified role", "guild_id", config.GuildID, "role_name", role.Name, "role_id", role.ID)
	return nil
}

// findRoleByName finds a role by name in the guild
func (m *ConfigManager) findRoleByName(session DiscordSession, guildID, roleName string) string {
	roles, err := session.GuildRoles(guildID)
	if err != nil {
		return ""
	}

	for _, role := range roles {
		if strings.EqualFold(role.Name, roleName) {
			return role.ID
		}
	}

	return ""
}

// roleExists checks if a role exists in the guild
func (m *ConfigManager) roleExists(session DiscordSession, guildID, roleID string) bool {
	roles, err := session.GuildRoles(guildID)
	if err != nil {
		return false
	}

	for _, role := range roles {
		if role.ID == roleID {
			return true
		}
	}

	return false
}

// RefreshGuildConfig forces a refresh of guild configuration from storage
func (m *ConfigManager) RefreshGuildConfig(session DiscordSession, guildID string) (*storage.GuildConfig, error) {
	// If using cached store, invalidate cache first
	if cachedStore, ok := m.store.(*storage.CachedConfigStore); ok {
		cachedStore.InvalidateCache(guildID)
	}

	return m.EnsureGuildConfig(session, guildID)
}