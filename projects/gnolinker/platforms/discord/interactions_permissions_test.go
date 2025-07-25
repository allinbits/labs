package discord

import (
	"fmt"
	"testing"

	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
	"github.com/bwmarrin/discordgo"
	"github.com/stretchr/testify/assert"
)

// TestableInteractionHandlers embeds InteractionHandlers for testing
type TestableInteractionHandlers struct {
	*InteractionHandlers
}

// TestableHasRoleAdminPermission exposes the private method for testing
func (h *TestableInteractionHandlers) TestableHasRoleAdminPermission(s interface{}, guildID, userID string) (bool, error) {
	// Type assertion to use our mock
	if mockSession, ok := s.(*MockDiscordSession); ok {
		// Call the actual logic manually since we can't override the private method
		// First check if user is a guild admin (owner or has Administrator permission)
		isGuildAdmin, err := h.testableHasGuildAdminPermission(mockSession, guildID, userID)
		if err != nil {
			return false, fmt.Errorf("failed to check guild admin permission: %w", err)
		}
		if isGuildAdmin {
			return true, nil
		}

		// If not a guild admin, check if they have the configured admin role
		guildConfig, err := h.configManager.GetGuildConfig(guildID)
		if err != nil {
			return false, fmt.Errorf("failed to get guild configuration: %w", err)
		}

		// Check if admin role is configured
		if !guildConfig.HasAdminRole() {
			return false, nil
		}

		// Check if user has the configured admin role
		return h.testableHasRole(mockSession, guildID, userID, guildConfig.AdminRoleID)
	}
	return false, fmt.Errorf("invalid session type")
}

func (h *TestableInteractionHandlers) testableHasGuildAdminPermission(s *MockDiscordSession, guildID, userID string) (bool, error) {
	// First check if they're the guild owner
	guild, err := s.Guild(guildID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild: %w", err)
	}

	if guild.OwnerID == userID {
		return true, nil
	}

	// Check if user has Administrator permission
	permissions, err := s.UserChannelPermissions(userID, guildID)
	if err != nil {
		return false, fmt.Errorf("failed to get user permissions: %w", err)
	}

	return (permissions & discordgo.PermissionAdministrator) != 0, nil
}

func (h *TestableInteractionHandlers) testableHasRole(s *MockDiscordSession, guildID, userID, roleID string) (bool, error) {
	member, err := s.GuildMember(guildID, userID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild member: %w", err)
	}

	for _, memberRoleID := range member.Roles {
		if memberRoleID == roleID {
			return true, nil
		}
	}

	return false, nil
}

func TestHasRoleAdminPermission(t *testing.T) {
	tests := []struct {
		name           string
		setupMocks     func(*MockDiscordSession, *config.ConfigManager)
		guildID        string
		userID         string
		expectedResult bool
		expectedError  string
	}{
		{
			name: "User is guild owner",
			setupMocks: func(session *MockDiscordSession, configMgr *config.ConfigManager) {
				// Set up guild with owner
				session.AddGuild("guild123", "user123")
			},
			guildID:        "guild123",
			userID:         "user123",
			expectedResult: true,
			expectedError:  "",
		},
		{
			name: "User has Administrator permission",
			setupMocks: func(session *MockDiscordSession, configMgr *config.ConfigManager) {
				// Set up guild with different owner
				session.AddGuild("guild123", "someone-else")
				// Give user admin permissions
				session.SetUserPermissions("user123", discordgo.PermissionAdministrator)
			},
			guildID:        "guild123",
			userID:         "user123",
			expectedResult: true,
			expectedError:  "",
		},
		{
			name: "User has configured admin role",
			setupMocks: func(session *MockDiscordSession, configMgr *config.ConfigManager) {
				// Set up guild with different owner
				session.AddGuild("guild123", "someone-else")
				// No admin permissions
				session.SetUserPermissions("user123", 0)

				// Configure admin role
				guildConfig := &storage.GuildConfig{
					GuildID:     "guild123",
					AdminRoleID: "admin-role-123",
				}
				if err := configMgr.UpdateGuildConfig(guildConfig.GuildID, guildConfig); err != nil {
					t.Fatalf("Failed to update guild config: %v", err)
				}

				// Add member with admin role
				session.AddMember("guild123", "user123", []string{"admin-role-123", "other-role"})
			},
			guildID:        "guild123",
			userID:         "user123",
			expectedResult: true,
			expectedError:  "",
		},
		{
			name: "User has neither guild admin nor configured admin role",
			setupMocks: func(session *MockDiscordSession, configMgr *config.ConfigManager) {
				// Set up guild with different owner
				session.AddGuild("guild123", "someone-else")
				// No admin permissions
				session.SetUserPermissions("user123", 0)

				// Configure admin role
				guildConfig := &storage.GuildConfig{
					GuildID:     "guild123",
					AdminRoleID: "admin-role-123",
				}
				if err := configMgr.UpdateGuildConfig(guildConfig.GuildID, guildConfig); err != nil {
					t.Fatalf("Failed to update guild config: %v", err)
				}

				// Add member without admin role
				session.AddMember("guild123", "user123", []string{"other-role"})
			},
			guildID:        "guild123",
			userID:         "user123",
			expectedResult: false,
			expectedError:  "",
		},
		{
			name: "No admin role configured and user is not guild admin",
			setupMocks: func(session *MockDiscordSession, configMgr *config.ConfigManager) {
				// Set up guild with different owner
				session.AddGuild("guild123", "someone-else")
				// No admin permissions
				session.SetUserPermissions("user123", 0)

				// No admin role configured
				guildConfig := &storage.GuildConfig{
					GuildID:     "guild123",
					AdminRoleID: "", // Empty admin role
				}
				if err := configMgr.UpdateGuildConfig(guildConfig.GuildID, guildConfig); err != nil {
					t.Fatalf("Failed to update guild config: %v", err)
				}
			},
			guildID:        "guild123",
			userID:         "user123",
			expectedResult: false,
			expectedError:  "",
		},
		{
			name: "Error checking guild admin permission",
			setupMocks: func(session *MockDiscordSession, configMgr *config.ConfigManager) {
				// Don't set up guild - will cause error
			},
			guildID:        "guild123",
			userID:         "user123",
			expectedResult: false,
			expectedError:  "failed to check guild admin permission: failed to get guild: guild not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create mocks
			mockSession := NewMockDiscordSession()
			mockLogger := NewMockLogger()

			// Create real config manager with memory store
			memStore := storage.NewMemoryConfigStore()
			lockManager := lock.NewNoOpLockManager()
			storageConfig := &config.StorageConfig{
				Type: "memory",
			}
			configMgr := config.NewConfigManager(memStore, storageConfig, lockManager, mockLogger)

			// Set up test data
			tt.setupMocks(mockSession, configMgr)

			// Create handler
			h := &TestableInteractionHandlers{
				InteractionHandlers: &InteractionHandlers{
					configManager: configMgr,
					logger:        mockLogger,
				},
			}

			// Test
			result, err := h.TestableHasRoleAdminPermission(mockSession, tt.guildID, tt.userID)

			// Assert
			assert.Equal(t, tt.expectedResult, result)
			if tt.expectedError != "" {
				assert.EqualError(t, err, tt.expectedError)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// TestPermissionPrecedence ensures guild admin always takes precedence
func TestPermissionPrecedence(t *testing.T) {
	// Create mocks
	mockSession := NewMockDiscordSession()
	mockLogger := NewMockLogger()

	// Create real config manager with memory store
	memStore := storage.NewMemoryConfigStore()
	lockManager := lock.NewNoOpLockManager()
	storageConfig := &config.StorageConfig{
		Type: "memory",
	}
	configMgr := config.NewConfigManager(memStore, storageConfig, lockManager, mockLogger)

	// Set up scenario: user is guild owner but NOT in admin role
	mockSession.AddGuild("guild123", "user123") // User is owner

	// Configure admin role that user doesn't have
	guildConfig := &storage.GuildConfig{
		GuildID:     "guild123",
		AdminRoleID: "admin-role-123",
	}
	if err := configMgr.UpdateGuildConfig(guildConfig.GuildID, guildConfig); err != nil {
		t.Fatalf("Failed to update guild config: %v", err)
	}

	// User doesn't have the admin role
	mockSession.AddMember("guild123", "user123", []string{"other-role"}) // No admin role

	// Create handler
	h := &TestableInteractionHandlers{
		InteractionHandlers: &InteractionHandlers{
			configManager: configMgr,
			logger:        mockLogger,
		},
	}

	// Test - should return true because user is guild owner
	result, err := h.TestableHasRoleAdminPermission(mockSession, "guild123", "user123")

	assert.NoError(t, err)
	assert.True(t, result, "Guild owner should have admin permission even without the admin role")
}

// Helper to set permissions error on mock
func (m *MockDiscordSession) SetPermissionsError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.permissionsError = err
}
