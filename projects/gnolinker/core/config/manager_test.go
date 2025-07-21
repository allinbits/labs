package config

import (
	"errors"
	"fmt"
	"sync"
	"testing"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
	"github.com/bwmarrin/discordgo"
)

// MockDiscordSession for ConfigManager testing
type MockDiscordSession struct {
	mu       sync.RWMutex
	roles    map[string][]*discordgo.Role
	rolesErr error
}

func NewMockDiscordSession() *MockDiscordSession {
	return &MockDiscordSession{
		roles: make(map[string][]*discordgo.Role),
	}
}

func (m *MockDiscordSession) GuildRoles(guildID string, options ...discordgo.RequestOption) ([]*discordgo.Role, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.rolesErr != nil {
		return nil, m.rolesErr
	}

	roles := m.roles[guildID]
	if roles == nil {
		return []*discordgo.Role{}, nil
	}

	// Return copy
	result := make([]*discordgo.Role, len(roles))
	copy(result, roles)
	return result, nil
}

func (m *MockDiscordSession) GuildRoleCreate(guildID string, data *discordgo.RoleParams, options ...discordgo.RequestOption) (*discordgo.Role, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	role := &discordgo.Role{
		ID:       fmt.Sprintf("role_%d", len(m.roles[guildID])+1),
		Name:     data.Name,
		Color:    *data.Color,
		Position: 1,
	}

	if m.roles[guildID] == nil {
		m.roles[guildID] = []*discordgo.Role{}
	}
	m.roles[guildID] = append(m.roles[guildID], role)

	return role, nil
}

func (m *MockDiscordSession) GuildRoleDelete(guildID, roleID string, options ...discordgo.RequestOption) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	roles := m.roles[guildID]
	for i, role := range roles {
		if role.ID == roleID {
			m.roles[guildID] = append(roles[:i], roles[i+1:]...)
			return nil
		}
	}

	return fmt.Errorf("role not found")
}

func (m *MockDiscordSession) SetRolesError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.rolesErr = err
}

func (m *MockDiscordSession) AddRole(guildID string, role *discordgo.Role) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.roles[guildID] == nil {
		m.roles[guildID] = []*discordgo.Role{}
	}
	// Create a copy to avoid external modification
	roleCopy := *role
	m.roles[guildID] = append(m.roles[guildID], &roleCopy)
}

// MockLogger for testing
type MockLogger struct {
	mu       sync.RWMutex
	messages []LogMessage
}

type LogMessage struct {
	Level string
	Msg   string
	Args  []any
}

func NewMockLogger() *MockLogger {
	return &MockLogger{
		messages: make([]LogMessage, 0),
	}
}

func (l *MockLogger) Debug(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "DEBUG", Msg: msg, Args: args})
}

func (l *MockLogger) Info(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "INFO", Msg: msg, Args: args})
}

func (l *MockLogger) Warn(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "WARN", Msg: msg, Args: args})
}

func (l *MockLogger) Error(msg string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.messages = append(l.messages, LogMessage{Level: "ERROR", Msg: msg, Args: args})
}

func (l *MockLogger) With(args ...any) core.Logger {
	return l
}

func (l *MockLogger) WithGroup(name string) core.Logger {
	return l
}

func (l *MockLogger) HasMessage(level, msgSubstring string) bool {
	l.mu.RLock()
	defer l.mu.RUnlock()

	for _, msg := range l.messages {
		if msg.Level == level && contains(msg.Msg, msgSubstring) {
			return true
		}
	}
	return false
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) &&
		(s == substr ||
			(len(s) > len(substr) && (s[:len(substr)] == substr || contains(s[1:], substr))))
}

func TestNewConfigManager(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{
		Type:                    "memory",
		AutoCreateRoles:         true,
		DefaultVerifiedRoleName: "Verified",
	}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()

	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	if manager == nil {
		t.Fatal("NewConfigManager() returned nil")
	}

	if manager.store != store {
		t.Error("ConfigManager store not set correctly")
	}

	if manager.storageConfig != storageConfig {
		t.Error("ConfigManager storageConfig not set correctly")
	}

	if manager.lockManager != lockManager {
		t.Error("ConfigManager lockManager not set correctly")
	}

	if manager.logger != logger {
		t.Error("ConfigManager logger not set correctly")
	}
}

func TestConfigManager_EnsureGuildConfig_NewGuild(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{
		Type:                    "memory",
		AutoCreateRoles:         true,
		DefaultVerifiedRoleName: "Gno-Verified",
	}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()
	guildID := "test-guild-123"

	// Add an admin role to be detected
	session.AddRole(guildID, &discordgo.Role{
		ID:          "admin-role-456",
		Name:        "Administrator",
		Permissions: discordgo.PermissionAdministrator,
		Managed:     false,
	})

	config, err := manager.EnsureGuildConfig(session, guildID)
	if err != nil {
		t.Fatalf("EnsureGuildConfig() failed: %v", err)
	}

	if config == nil {
		t.Fatal("EnsureGuildConfig() returned nil config")
	}

	if config.GuildID != guildID {
		t.Errorf("Config GuildID = %q, want %q", config.GuildID, guildID)
	}

	// Should have detected admin role
	if config.AdminRoleID != "admin-role-456" {
		t.Errorf("Config AdminRoleID = %q, want %q", config.AdminRoleID, "admin-role-456")
	}

	// Should have created verified role
	if config.VerifiedRoleID == "" {
		t.Error("Config VerifiedRoleID should not be empty")
	}

	// Should log creation
	if !logger.HasMessage("INFO", "Creating new guild configuration") {
		t.Error("Should log guild configuration creation")
	}

	if !logger.HasMessage("INFO", "Successfully created guild configuration") {
		t.Error("Should log successful guild configuration creation")
	}
}

func TestConfigManager_EnsureGuildConfig_ExistingGuild(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{
		Type:                    "memory",
		AutoCreateRoles:         true,
		DefaultVerifiedRoleName: "Gno-Verified",
	}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()
	guildID := "existing-guild-789"

	// Create existing config
	existingConfig := storage.NewGuildConfig(guildID)
	existingConfig.AdminRoleID = "existing-admin-123"
	existingConfig.VerifiedRoleID = "existing-verified-456"

	err := store.Set(guildID, existingConfig)
	if err != nil {
		t.Fatalf("Failed to set existing config: %v", err)
	}

	// Add corresponding roles to session
	session.AddRole(guildID, &discordgo.Role{
		ID:   "existing-admin-123",
		Name: "Admin",
	})
	session.AddRole(guildID, &discordgo.Role{
		ID:   "existing-verified-456",
		Name: "Gno-Verified",
	})

	config, err := manager.EnsureGuildConfig(session, guildID)
	if err != nil {
		t.Fatalf("EnsureGuildConfig() failed: %v", err)
	}

	if config.AdminRoleID != "existing-admin-123" {
		t.Errorf("Config AdminRoleID = %q, want %q", config.AdminRoleID, "existing-admin-123")
	}

	if config.VerifiedRoleID != "existing-verified-456" {
		t.Errorf("Config VerifiedRoleID = %q, want %q", config.VerifiedRoleID, "existing-verified-456")
	}

	// Should not log creation for existing guild
	if logger.HasMessage("INFO", "Creating new guild configuration") {
		t.Error("Should not log guild configuration creation for existing guild")
	}
}

func TestConfigManager_EnsureGuildConfig_RepairMissingRoles(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{
		Type:                    "memory",
		AutoCreateRoles:         true,
		DefaultVerifiedRoleName: "Gno-Verified",
	}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()
	guildID := "repair-guild-999"

	// Create config with roles that no longer exist
	existingConfig := storage.NewGuildConfig(guildID)
	existingConfig.AdminRoleID = "missing-admin-123"
	existingConfig.VerifiedRoleID = "missing-verified-456"

	err := store.Set(guildID, existingConfig)
	if err != nil {
		t.Fatalf("Failed to set existing config: %v", err)
	}

	config, err := manager.EnsureGuildConfig(session, guildID)
	if err != nil {
		t.Fatalf("EnsureGuildConfig() failed: %v", err)
	}

	// Should have cleared missing admin role
	if config.AdminRoleID != "" {
		t.Errorf("Config AdminRoleID should be cleared, got %q", config.AdminRoleID)
	}

	// Should have recreated verified role
	if config.VerifiedRoleID == "" {
		t.Error("Config VerifiedRoleID should be recreated")
	}

	// Should log warnings about missing roles
	if !logger.HasMessage("WARN", "Admin role no longer exists") {
		t.Error("Should log warning about missing admin role")
	}

	if !logger.HasMessage("WARN", "Verified role no longer exists") {
		t.Error("Should log warning about missing verified role")
	}
}

func TestConfigManager_GetGuildConfig(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	guildID := "test-guild-456"

	// Should return error for non-existent config
	_, err := manager.GetGuildConfig(guildID)
	if err == nil {
		t.Fatal("GetGuildConfig() should return error for non-existent config")
	}

	// Create config
	config := storage.NewGuildConfig(guildID)
	err = store.Set(guildID, config)
	if err != nil {
		t.Fatalf("Failed to set config: %v", err)
	}

	// Should return config
	retrieved, err := manager.GetGuildConfig(guildID)
	if err != nil {
		t.Fatalf("GetGuildConfig() failed: %v", err)
	}

	if retrieved.GuildID != guildID {
		t.Errorf("Retrieved GuildID = %q, want %q", retrieved.GuildID, guildID)
	}
}

func TestConfigManager_UpdateGuildConfig(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	guildID := "update-guild-789"
	config := storage.NewGuildConfig(guildID)
	config.AdminRoleID = "new-admin-123"

	err := manager.UpdateGuildConfig(guildID, config)
	if err != nil {
		t.Fatalf("UpdateGuildConfig() failed: %v", err)
	}

	// Verify update
	retrieved, err := store.Get(guildID)
	if err != nil {
		t.Fatalf("Failed to get updated config: %v", err)
	}

	if retrieved.AdminRoleID != "new-admin-123" {
		t.Errorf("Updated AdminRoleID = %q, want %q", retrieved.AdminRoleID, "new-admin-123")
	}
}

func TestConfigManager_DeleteGuildConfig(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	guildID := "delete-guild-101"
	config := storage.NewGuildConfig(guildID)

	// Create config
	err := store.Set(guildID, config)
	if err != nil {
		t.Fatalf("Failed to set config: %v", err)
	}

	// Delete config
	err = manager.DeleteGuildConfig(guildID)
	if err != nil {
		t.Fatalf("DeleteGuildConfig() failed: %v", err)
	}

	// Verify deletion
	_, err = store.Get(guildID)
	if err == nil {
		t.Fatal("Config should be deleted")
	}
}

func TestConfigManager_GetStorageConfig(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{
		Type:            "memory",
		AutoCreateRoles: true,
	}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	retrieved := manager.GetStorageConfig()
	if retrieved != storageConfig {
		t.Error("GetStorageConfig() should return the same instance")
	}
}

func TestConfigManager_GetLockManager(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	retrieved := manager.GetLockManager()
	if retrieved != lockManager {
		t.Error("GetLockManager() should return the same instance")
	}
}

func TestConfigManager_DetectAdminRole(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()
	guildID := "admin-detect-guild"

	tests := []struct {
		name     string
		roles    []*discordgo.Role
		expected string
	}{
		{
			name: "administrator permission role",
			roles: []*discordgo.Role{
				{
					ID:          "admin-perm-123",
					Name:        "Server Admin",
					Permissions: discordgo.PermissionAdministrator,
					Managed:     false,
				},
			},
			expected: "admin-perm-123",
		},
		{
			name: "admin name role",
			roles: []*discordgo.Role{
				{
					ID:          "admin-name-456",
					Name:        "Administrator",
					Permissions: 0,
					Managed:     false,
				},
			},
			expected: "admin-name-456",
		},
		{
			name: "moderator name role",
			roles: []*discordgo.Role{
				{
					ID:          "mod-name-789",
					Name:        "Moderator",
					Permissions: 0,
					Managed:     false,
				},
			},
			expected: "mod-name-789",
		},
		{
			name: "everyone role ignored",
			roles: []*discordgo.Role{
				{
					ID:          "everyone-123",
					Name:        "@everyone",
					Permissions: discordgo.PermissionAdministrator,
					Managed:     false,
				},
			},
			expected: "",
		},
		{
			name: "managed role ignored",
			roles: []*discordgo.Role{
				{
					ID:          "bot-role-456",
					Name:        "Bot Admin",
					Permissions: discordgo.PermissionAdministrator,
					Managed:     true,
				},
			},
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear roles
			session.mu.Lock()
			session.roles[guildID] = []*discordgo.Role{}
			session.mu.Unlock()

			// Add test roles
			for _, role := range tt.roles {
				session.AddRole(guildID, role)
			}

			result := manager.detectAdminRole(session, guildID)
			if result != tt.expected {
				t.Errorf("detectAdminRole() = %q, want %q", result, tt.expected)
			}
		})
	}
}

func TestConfigManager_RoleExists(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()
	guildID := "role-exists-guild"

	// Add a role
	session.AddRole(guildID, &discordgo.Role{
		ID:   "existing-role-123",
		Name: "Test Role",
	})

	// Should find existing role
	if !manager.roleExists(session, guildID, "existing-role-123") {
		t.Error("roleExists() should return true for existing role")
	}

	// Should not find non-existent role
	if manager.roleExists(session, guildID, "non-existent-456") {
		t.Error("roleExists() should return false for non-existent role")
	}
}

func TestConfigManager_FindRoleByName(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()
	guildID := "find-role-guild"

	// Add roles
	session.AddRole(guildID, &discordgo.Role{
		ID:   "role-123",
		Name: "Test Role",
	})
	session.AddRole(guildID, &discordgo.Role{
		ID:   "role-456",
		Name: "Another Role",
	})

	// Should find exact match
	roleID := manager.findRoleByName(session, guildID, "Test Role")
	if roleID != "role-123" {
		t.Errorf("findRoleByName() = %q, want %q", roleID, "role-123")
	}

	// Should find case-insensitive match
	roleID = manager.findRoleByName(session, guildID, "test role")
	if roleID != "role-123" {
		t.Errorf("findRoleByName() case-insensitive = %q, want %q", roleID, "role-123")
	}

	// Should not find non-existent role
	roleID = manager.findRoleByName(session, guildID, "Non-existent Role")
	if roleID != "" {
		t.Errorf("findRoleByName() for non-existent = %q, want empty", roleID)
	}
}

func TestConfigManager_GuildRolesError(t *testing.T) {
	t.Parallel()
	store := storage.NewMemoryConfigStore()
	storageConfig := &StorageConfig{
		AutoCreateRoles: false, // Disable auto-create to avoid role creation attempts
	}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	manager := NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()
	guildID := "error-guild-123"

	// Set up error
	session.SetRolesError(errors.New("API error"))

	// Should handle error gracefully
	config, err := manager.EnsureGuildConfig(session, guildID)
	if err != nil {
		t.Fatalf("EnsureGuildConfig() should handle GuildRoles error gracefully: %v", err)
	}

	if config == nil {
		t.Fatal("EnsureGuildConfig() should return config even with GuildRoles error")
	}

	// Should log error
	if !logger.HasMessage("ERROR", "Failed to get guild roles for admin detection") {
		t.Error("Should log error about failed guild roles API call")
	}
}
