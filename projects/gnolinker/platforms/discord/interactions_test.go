package discord

import (
	"errors"
	"sync"
	"testing"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
	"github.com/bwmarrin/discordgo"
)

// Mock workflow types (simplified for testing)
type MockUserClaim struct {
	UserID    string
	Address   string
	Signature string
}

type MockRoleClaim struct {
	UserID         string
	GuildID        string
	PlatformRoleID string
	RealmRoleName  string
	RealmPath      string
	Signature      string
}

type MockRoleMapping struct {
	RealmRoleName string
	PlatformRole  *core.PlatformRole
}

type MockRoleStatus struct {
	IsMember    bool
	RoleMapping *MockRoleMapping
}

// Mock workflows
type MockUserLinkingWorkflow struct {
	mu              sync.RWMutex
	linkedAddresses map[string]string // userID -> address
	claims          map[string]*MockUserClaim
	claimURL        string
}

func NewMockUserLinkingWorkflow() *MockUserLinkingWorkflow {
	return &MockUserLinkingWorkflow{
		linkedAddresses: make(map[string]string),
		claims:          make(map[string]*MockUserClaim),
		claimURL:        "https://example.com/claim/user",
	}
}

func (m *MockUserLinkingWorkflow) GenerateClaim(userID, address string) (*MockUserClaim, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	claim := &MockUserClaim{
		UserID:    userID,
		Address:   address,
		Signature: "mock_signature_" + userID + "_" + address,
	}
	m.claims[userID] = claim
	return claim, nil
}

func (m *MockUserLinkingWorkflow) GetLinkedAddress(userID string) (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	address, exists := m.linkedAddresses[userID]
	if !exists {
		return "", nil
	}
	return address, nil
}

func (m *MockUserLinkingWorkflow) GetClaimURL(claim *MockUserClaim) string {
	return m.claimURL
}

func (m *MockUserLinkingWorkflow) SetLinkedAddress(userID, address string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.linkedAddresses[userID] = address
}

type MockRoleLinkingWorkflow struct {
	mu          sync.RWMutex
	linkedRoles map[string]*MockRoleMapping // key: realm_role_guild -> mapping
	claims      map[string]*MockRoleClaim
	claimURL    string
}

func NewMockRoleLinkingWorkflow() *MockRoleLinkingWorkflow {
	return &MockRoleLinkingWorkflow{
		linkedRoles: make(map[string]*MockRoleMapping),
		claims:      make(map[string]*MockRoleClaim),
		claimURL:    "https://example.com/claim/role",
	}
}

func (m *MockRoleLinkingWorkflow) GenerateClaim(userID, guildID, platformRoleID, roleName, realmPath string) (*MockRoleClaim, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	claim := &MockRoleClaim{
		UserID:         userID,
		GuildID:        guildID,
		PlatformRoleID: platformRoleID,
		RealmRoleName:  roleName,
		RealmPath:      realmPath,
		Signature:      "mock_role_signature_" + userID + "_" + roleName,
	}
	m.claims[userID] = claim
	return claim, nil
}

func (m *MockRoleLinkingWorkflow) GetLinkedRole(realmPath, roleName, guildID string) (*MockRoleMapping, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	key := realmPath + "_" + roleName + "_" + guildID
	mapping, exists := m.linkedRoles[key]
	if !exists {
		return nil, errors.New("role mapping not found")
	}
	return mapping, nil
}

func (m *MockRoleLinkingWorkflow) GetClaimURL(claim *MockRoleClaim) string {
	return m.claimURL
}

func (m *MockRoleLinkingWorkflow) SetLinkedRole(realmPath, roleName, guildID string, mapping *MockRoleMapping) {
	m.mu.Lock()
	defer m.mu.Unlock()
	key := realmPath + "_" + roleName + "_" + guildID
	m.linkedRoles[key] = mapping
}

type MockSyncWorkflow struct {
	mu        sync.RWMutex
	syncError error
	statuses  map[string][]*MockRoleStatus // userID -> statuses
}

func NewMockSyncWorkflow() *MockSyncWorkflow {
	return &MockSyncWorkflow{
		statuses: make(map[string][]*MockRoleStatus),
	}
}

func (m *MockSyncWorkflow) SyncUserRoles(userID, realmPath, guildID string) ([]*MockRoleStatus, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.syncError != nil {
		return nil, m.syncError
	}

	statuses, exists := m.statuses[userID]
	if !exists {
		return []*MockRoleStatus{}, nil
	}
	return statuses, nil
}

func (m *MockSyncWorkflow) SetSyncError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.syncError = err
}

func (m *MockSyncWorkflow) SetUserStatuses(userID string, statuses []*MockRoleStatus) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.statuses[userID] = statuses
}

// Test setup helper
func setupInteractionHandlers() (*InteractionHandlers, *MockDiscordSession, *config.ConfigManager, *MockLogger) {
	store := storage.NewMemoryConfigStore()
	storageConfig := &config.StorageConfig{
		Type:                    "memory",
		AutoCreateRoles:         true,
		DefaultVerifiedRoleName: "Gno-Verified",
	}
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	configManager := config.NewConfigManager(store, storageConfig, lockManager, logger)

	session := NewMockDiscordSession()

	// Create minimal handler for testing
	handlers := &InteractionHandlers{
		configManager: configManager,
		logger:        logger,
	}

	return handlers, session, configManager, logger
}

func TestNewInteractionHandlers_Basic(t *testing.T) {
	t.Parallel()
	t.Skip("Skipping test that requires real workflow implementations")
}

func TestParseRoleLinkParams(t *testing.T) {
	t.Parallel()
	tests := []struct {
		input    string
		expected []string
	}{
		{
			input:    "admin_/r/demo/boards",
			expected: []string{"admin", "/r/demo/boards"},
		},
		{
			input:    "moderator_/r/demo/users",
			expected: []string{"moderator", "/r/demo/users"},
		},
		{
			input:    "invalid",
			expected: []string{},
		},
		{
			input:    "",
			expected: []string{},
		},
		{
			input:    "role_with_underscores_/r/demo/test",
			expected: []string{"role_with_underscores", "/r/demo/test"},
		},
	}

	for _, tt := range tests {
		t.Run("input_"+tt.input, func(t *testing.T) {
			result := parseRoleLinkParams(tt.input)

			if len(result) != len(tt.expected) {
				t.Errorf("parseRoleLinkParams(%q) returned %d parts, want %d", tt.input, len(result), len(tt.expected))
				return
			}

			for i, part := range result {
				if part != tt.expected[i] {
					t.Errorf("parseRoleLinkParams(%q)[%d] = %q, want %q", tt.input, i, part, tt.expected[i])
				}
			}
		})
	}
}

// Test role link params with various edge cases
func TestParseRoleLinkParams_EdgeCases(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name     string
		input    string
		expected []string
	}{
		{
			name:     "multiple underscores in role name",
			input:    "role_with_many_underscores_/r/demo/boards",
			expected: []string{"role_with_many_underscores", "/r/demo/boards"},
		},
		{
			name:     "underscore at end of role name",
			input:    "role__/r/demo/boards",
			expected: []string{"role_", "/r/demo/boards"},
		},
		{
			name:     "empty role name",
			input:    "_/r/demo/boards",
			expected: []string{},
		},
		{
			name:     "only underscores",
			input:    "___",
			expected: []string{},
		},
		{
			name:     "no realm path separator",
			input:    "admin",
			expected: []string{},
		},
		{
			name:     "realm path with underscores",
			input:    "admin_/r/demo/test_realm",
			expected: []string{"admin_/r/demo/test", "realm"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parseRoleLinkParams(tt.input)

			if len(result) != len(tt.expected) {
				t.Errorf("parseRoleLinkParams(%q) returned %d parts, want %d", tt.input, len(result), len(tt.expected))
				return
			}

			for i, part := range result {
				if part != tt.expected[i] {
					t.Errorf("parseRoleLinkParams(%q)[%d] = %q, want %q", tt.input, i, part, tt.expected[i])
				}
			}
		})
	}
}

// TestCommandsEqual tests the commandsEqual method
func TestCommandsEqual(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name         string
		cmd1         *discordgo.ApplicationCommand
		cmd2         *discordgo.ApplicationCommand
		expectedSame bool
	}{
		{
			name: "identical commands",
			cmd1: &discordgo.ApplicationCommand{
				Name:        "test",
				Description: "Test command",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionString,
						Name:        "param",
						Description: "A parameter",
						Required:    true,
					},
				},
			},
			cmd2: &discordgo.ApplicationCommand{
				Name:        "test",
				Description: "Test command",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionString,
						Name:        "param",
						Description: "A parameter",
						Required:    true,
					},
				},
			},
			expectedSame: true,
		},
		{
			name: "different names",
			cmd1: &discordgo.ApplicationCommand{
				Name:        "test1",
				Description: "Test command",
			},
			cmd2: &discordgo.ApplicationCommand{
				Name:        "test2",
				Description: "Test command",
			},
			expectedSame: false,
		},
		{
			name: "different descriptions",
			cmd1: &discordgo.ApplicationCommand{
				Name:        "test",
				Description: "Test command 1",
			},
			cmd2: &discordgo.ApplicationCommand{
				Name:        "test",
				Description: "Test command 2",
			},
			expectedSame: false,
		},
		{
			name: "different option counts",
			cmd1: &discordgo.ApplicationCommand{
				Name:        "test",
				Description: "Test command",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionString,
						Name:        "param1",
						Description: "Parameter 1",
					},
				},
			},
			cmd2: &discordgo.ApplicationCommand{
				Name:        "test",
				Description: "Test command",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionString,
						Name:        "param1",
						Description: "Parameter 1",
					},
					{
						Type:        discordgo.ApplicationCommandOptionString,
						Name:        "param2",
						Description: "Parameter 2",
					},
				},
			},
			expectedSame: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handlers := &InteractionHandlers{}
			result := handlers.commandsEqual(tt.cmd1, tt.cmd2)
			if result != tt.expectedSame {
				t.Errorf("commandsEqual() = %v, want %v", result, tt.expectedSame)
			}
		})
	}
}

// TestOptionEqual tests the optionEqual method
func TestOptionEqual(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name         string
		opt1         *discordgo.ApplicationCommandOption
		opt2         *discordgo.ApplicationCommandOption
		expectedSame bool
	}{
		{
			name: "identical options",
			opt1: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionString,
				Name:        "test",
				Description: "Test option",
				Required:    true,
			},
			opt2: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionString,
				Name:        "test",
				Description: "Test option",
				Required:    true,
			},
			expectedSame: true,
		},
		{
			name: "different types",
			opt1: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionString,
				Name:        "test",
				Description: "Test option",
			},
			opt2: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionInteger,
				Name:        "test",
				Description: "Test option",
			},
			expectedSame: false,
		},
		{
			name: "different names",
			opt1: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionString,
				Name:        "test1",
				Description: "Test option",
			},
			opt2: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionString,
				Name:        "test2",
				Description: "Test option",
			},
			expectedSame: false,
		},
		{
			name: "different required states",
			opt1: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionString,
				Name:        "test",
				Description: "Test option",
				Required:    true,
			},
			opt2: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionString,
				Name:        "test",
				Description: "Test option",
				Required:    false,
			},
			expectedSame: false,
		},
		{
			name: "with sub-options",
			opt1: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionSubCommand,
				Name:        "test",
				Description: "Test subcommand",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionString,
						Name:        "param",
						Description: "A parameter",
					},
				},
			},
			opt2: &discordgo.ApplicationCommandOption{
				Type:        discordgo.ApplicationCommandOptionSubCommand,
				Name:        "test",
				Description: "Test subcommand",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionString,
						Name:        "param",
						Description: "A parameter",
					},
				},
			},
			expectedSame: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handlers := &InteractionHandlers{}
			result := handlers.optionEqual(tt.opt1, tt.opt2)
			if result != tt.expectedSame {
				t.Errorf("optionEqual() = %v, want %v", result, tt.expectedSame)
			}
		})
	}
}

// TestFindOrphanedRoles tests the findOrphanedRoles method
func TestFindOrphanedRoles(t *testing.T) {
	t.Parallel()

	// Create test data
	managedRoles := []*core.RoleMapping{
		{
			RealmRoleName: "admin",
			PlatformRole: core.PlatformRole{
				ID:   "role1",
				Name: "Admin",
			},
		},
		{
			RealmRoleName: "moderator",
			PlatformRole: core.PlatformRole{
				ID:   "role2",
				Name: "Moderator",
			},
		},
	}

	guildRoles := []*discordgo.Role{
		{ID: "role1", Name: "Admin"},
		{ID: "role2", Name: "Moderator"},
		{ID: "role3", Name: "member-gno.land/r/demo/boards"},
		{ID: "role4", Name: "developer-gno.land/r/demo/users"},
		{ID: "role5", Name: "Regular Role"},
		{ID: "role6", Name: "verified-gno.land/r/demo/boards"},
	}

	handlers := &InteractionHandlers{}
	orphaned := handlers.findOrphanedRoles(managedRoles, guildRoles)

	if len(orphaned) != 3 {
		t.Errorf("Expected 3 orphaned roles, got %d", len(orphaned))
	}

	// Check that the correct roles were identified as orphaned
	expectedOrphaned := map[string]bool{
		"role3": true,
		"role4": true,
		"role6": true,
	}

	for _, orphan := range orphaned {
		if orphan.DiscordRole != nil && !expectedOrphaned[orphan.DiscordRole.ID] {
			t.Errorf("Unexpected orphaned role: %s", orphan.RoleName)
		}
	}
}

// TestFormatOrphanedRolesEmbed tests the formatOrphanedRolesEmbed method
func TestFormatOrphanedRolesEmbed(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name          string
		orphanedRoles []OrphanedRole
		expectedTitle string
		expectedColor int
	}{
		{
			name:          "no orphaned roles",
			orphanedRoles: []OrphanedRole{},
			expectedTitle: "✅ No Orphaned Roles",
			expectedColor: 0x00ff00,
		},
		{
			name: "with orphaned roles",
			orphanedRoles: []OrphanedRole{
				{Type: "discord-side", RoleName: "admin", DiscordRole: &discordgo.Role{ID: "1", Name: "admin-gno.land/r/demo/boards"}},
				{Type: "discord-side", RoleName: "moderator", DiscordRole: &discordgo.Role{ID: "2", Name: "moderator-gno.land/r/demo/users"}},
			},
			expectedTitle: "Orphaned Roles Check",
			expectedColor: 0xFFA500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handlers := &InteractionHandlers{}
			embed := handlers.formatOrphanedRolesEmbed(tt.orphanedRoles)
			if embed.Title != tt.expectedTitle {
				t.Errorf("Expected title %q, got %q", tt.expectedTitle, embed.Title)
			}
			if embed.Color != tt.expectedColor {
				t.Errorf("Expected color %d, got %d", tt.expectedColor, embed.Color)
			}
		})
	}
}

// TestRespondDeferredError tests the respondDeferredError method
func TestRespondDeferredError(t *testing.T) {
	t.Parallel()
	// Skip test that requires real Discord session implementation
	t.Skip("Skipping test that requires full Discord session implementation")
}

// TestGetExpectedCommands tests that the expected commands are returned
func TestGetExpectedCommands(t *testing.T) {
	t.Parallel()

	handlers := &InteractionHandlers{}
	commands := handlers.GetExpectedCommands()

	if len(commands) != 1 {
		t.Fatalf("Expected 1 command, got %d", len(commands))
	}

	cmd := commands[0]
	if cmd.Name != "gnolinker" {
		t.Errorf("Expected command name 'gnolinker', got %q", cmd.Name)
	}

	// Check for expected direct subcommands
	directSubcommands := []string{"link", "unlink", "status", "help", "admin"}
	foundSubcommands := make(map[string]bool)

	for _, opt := range cmd.Options {
		foundSubcommands[opt.Name] = true
	}

	for _, expected := range directSubcommands {
		if !foundSubcommands[expected] {
			t.Errorf("Expected to find subcommand %q", expected)
		}
	}
}

// TestCompareCommands tests the compareCommands method
func TestCompareCommands(t *testing.T) {
	t.Parallel()

	handlers := &InteractionHandlers{}

	// Test with identical command sets
	cmd1 := []*discordgo.ApplicationCommand{
		{
			Name:        "test1",
			Description: "Test command 1",
		},
		{
			Name:        "test2",
			Description: "Test command 2",
		},
	}

	cmd2 := []*discordgo.ApplicationCommand{
		{
			Name:        "test1",
			Description: "Test command 1",
		},
		{
			Name:        "test2",
			Description: "Test command 2",
		},
	}

	toCreate, toUpdate, toDelete := handlers.compareCommands(cmd1, cmd2)

	if len(toCreate) != 0 {
		t.Errorf("Expected no commands to create, got %d", len(toCreate))
	}
	if len(toDelete) != 0 {
		t.Errorf("Expected no commands to delete, got %d", len(toDelete))
	}
	if len(toUpdate) != 0 {
		t.Errorf("Expected no commands to update, got %d", len(toUpdate))
	}

	// Test with different command sets
	cmd3 := []*discordgo.ApplicationCommand{
		{
			Name:        "test1",
			Description: "Test command 1 - updated",
		},
		{
			Name:        "test3",
			Description: "Test command 3",
		},
	}

	toCreate, toUpdate, toDelete = handlers.compareCommands(cmd1, cmd3)

	if len(toCreate) != 1 || toCreate[0].Name != "test2" {
		t.Errorf("Expected to create 'test2', got %v", toCreate)
	}
	if len(toDelete) != 1 || toDelete[0].Name != "test3" {
		t.Errorf("Expected to delete 'test3', got %v", toDelete)
	}
	if len(toUpdate) != 1 || toUpdate[0].expected.Name != "test1" {
		t.Errorf("Expected to update 'test1', got %v", toUpdate)
	}
}

// TestInteractionHandlers_ErrorResponses tests error response methods
func TestInteractionHandlers_ErrorResponses(t *testing.T) {
	t.Parallel()
	// Skip tests that require real Discord session implementation
	t.Skip("Skipping tests that require full Discord session implementation")
}

// TestInteractionHandlers_CoreFunctionality validates basic handler setup
func TestInteractionHandlers_CoreFunctionality(t *testing.T) {
	t.Parallel()
	handlers, _, configManager, logger := setupInteractionHandlers()

	if handlers.configManager != configManager {
		t.Error("configManager not set correctly")
	}

	if handlers.logger != logger {
		t.Error("logger not set correctly")
	}
}
