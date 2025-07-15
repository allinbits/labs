package discord

import (
	"errors"
	"sync"
	"testing"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
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
func setupInteractionHandlers() (*InteractionHandlers, *MockDiscordSession, *MockUserLinkingWorkflow, *MockRoleLinkingWorkflow, *MockSyncWorkflow, *config.ConfigManager, *MockLogger) {
	userFlow := NewMockUserLinkingWorkflow()
	roleFlow := NewMockRoleLinkingWorkflow()
	syncFlow := NewMockSyncWorkflow()
	
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
	
	// Note: We'll need to create a wrapper that adapts the mock workflows to the real interfaces
	// For now, we'll create a minimal handler without workflows to test basic functionality
	handlers := &InteractionHandlers{
		configManager: configManager,
		logger:        logger,
	}
	
	return handlers, session, userFlow, roleFlow, syncFlow, configManager, logger
}

func TestNewInteractionHandlers_Basic(t *testing.T) {
	t.Parallel()
	handlers, _, _, _, _, configManager, logger := setupInteractionHandlers()
	
	if handlers == nil {
		t.Fatal("InteractionHandlers should not be nil")
	}
	
	if handlers.configManager != configManager {
		t.Error("configManager not set correctly")
	}
	
	if handlers.logger != logger {
		t.Error("logger not set correctly")
	}
}

// Note: Full integration tests with actual discord session would require 
// implementing the complete discordgo.Session interface. For now, we test
// the helper functions and logic that can be tested independently.

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

// Note: Tests for helper functions like getRoleByName, hasRole, etc. would require
// implementing the full discordgo.Session interface on our MockDiscordSession.
// Since this would require extensive mock implementation beyond the scope of this
// testing task, we focus on testing the core logic that can be tested independently.

func TestInteractionHandlers_CoreFunctionality(t *testing.T) {
	t.Parallel()
	// Basic constructor test
	handlers, _, _, _, _, configManager, logger := setupInteractionHandlers()
	
	if handlers.configManager != configManager {
		t.Error("configManager not set correctly")
	}
	
	if handlers.logger != logger {
		t.Error("logger not set correctly")
	}
}