package discord

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/bwmarrin/discordgo"
)

func TestNewRoleManager(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()

	rm := NewRoleManager(session, lockManager, logger)

	if rm == nil {
		t.Fatal("NewRoleManager() returned nil")
	}

	// Can't directly compare interface values, so just check if it's not nil
	if rm.session == nil {
		t.Error("RoleManager session should not be nil")
	}

	if rm.lockManager != lockManager {
		t.Error("RoleManager lockManager not set correctly")
	}

	if rm.logger != logger {
		t.Error("RoleManager logger not set correctly")
	}
}

func TestRoleManager_GetOrCreateRole_ExistingRole(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-123"
	roleName := "Verified"

	// Add existing role
	existingRole := &discordgo.Role{
		ID:   "existing-role-456",
		Name: roleName,
	}
	session.AddRole(guildID, existingRole)

	// Should return existing role
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() failed: %v", err)
	}

	if role == nil {
		t.Fatal("GetOrCreateRole() returned nil role")
	}

	if role.ID != existingRole.ID {
		t.Errorf("Role ID = %s, want %s", role.ID, existingRole.ID)
	}

	if role.Name != existingRole.Name {
		t.Errorf("Role Name = %s, want %s", role.Name, existingRole.Name)
	}

	// Should log debug message about finding existing role
	if !logger.HasMessage("DEBUG", "Found existing role") {
		t.Error("Should log debug message about finding existing role")
	}
}

func TestRoleManager_GetOrCreateRole_CreateNew(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-789"
	roleName := "NewRole"
	color := 0xFF0000

	// Should create new role
	role, err := rm.GetOrCreateRole(guildID, roleName, &color)
	if err != nil {
		t.Fatalf("GetOrCreateRole() failed: %v", err)
	}

	if role == nil {
		t.Fatal("GetOrCreateRole() returned nil role")
	}

	if role.Name != roleName {
		t.Errorf("Role Name = %s, want %s", role.Name, roleName)
	}

	// Should log info message about creating role
	if !logger.HasMessage("INFO", "Created new Discord role") {
		t.Error("Should log info message about creating new role")
	}

	// Verify role was actually created in mock session
	roles, err := session.GuildRoles(guildID)
	if err != nil {
		t.Fatalf("Failed to get roles: %v", err)
	}

	found := false
	for _, r := range roles {
		if r.Name == roleName && r.Color == color {
			found = true
			break
		}
	}

	if !found {
		t.Error("Role was not created in Discord session")
	}
}

func TestRoleManager_GetOrCreateRole_NoLockManager(t *testing.T) {
	session := NewMockDiscordSession()
	logger := NewMockLogger()
	rm := NewRoleManager(session, nil, logger) // No lock manager

	guildID := "test-guild-no-lock"
	roleName := "TestRole"

	// Should still work without lock manager
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() without lock manager failed: %v", err)
	}

	if role == nil {
		t.Fatal("GetOrCreateRole() returned nil role")
	}

	if role.Name != roleName {
		t.Errorf("Role Name = %s, want %s", role.Name, roleName)
	}
}

func TestRoleManager_GetOrCreateRole_LockAcquisitionFails(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewMemoryLockManager(lock.LockConfig{
		DefaultTTL:    30 * time.Second,
		RetryInterval: 10 * time.Millisecond,
		MaxRetries:    0, // Fail immediately
	})
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-lock-fail"
	roleName := "LockedRole"

	// Acquire lock first to block the role manager
	ctx := context.Background()
	lockKey := fmt.Sprintf("role:create:%s:%s", guildID, "LockedRole")
	_, err := lockManager.AcquireLock(ctx, lockKey, time.Minute)
	if err != nil {
		t.Fatalf("Failed to acquire blocking lock: %v", err)
	}

	// Should fail to get lock and return error
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err == nil {
		t.Fatal("GetOrCreateRole() should fail when lock acquisition fails")
	}

	if role != nil {
		t.Error("GetOrCreateRole() should return nil role when lock acquisition fails")
	}

	// Should log warning about lock acquisition failure
	if !logger.HasMessage("WARN", "Failed to acquire lock for role creation") {
		t.Error("Should log warning about lock acquisition failure")
	}
}

func TestRoleManager_GetOrCreateRole_RoleCreatedByOtherInstance(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewMemoryLockManager(lock.LockConfig{
		DefaultTTL:    30 * time.Second,
		RetryInterval: 10 * time.Millisecond,
		MaxRetries:    0, // Fail immediately
	})
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-race"
	roleName := "RaceRole"

	// Acquire lock first to block the role manager
	ctx := context.Background()
	lockKey := fmt.Sprintf("role:create:%s:%s", guildID, "RaceRole")
	blockingLock, err := lockManager.AcquireLock(ctx, lockKey, time.Minute)
	if err != nil {
		t.Fatalf("Failed to acquire blocking lock: %v", err)
	}

	// Simulate another instance creating the role while locked
	go func() {
		time.Sleep(50 * time.Millisecond)
		session.AddRole(guildID, &discordgo.Role{
			ID:   "race-role-123",
			Name: roleName,
		})
		// Release the lock after adding the role
		lockManager.ReleaseLock(ctx, blockingLock)
	}()

	// Should find the role created by "other instance"
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() failed: %v", err)
	}

	if role == nil {
		t.Fatal("GetOrCreateRole() returned nil role")
	}

	if role.ID != "race-role-123" {
		t.Errorf("Role ID = %s, want %s", role.ID, "race-role-123")
	}

	// Should log info about role being created by another instance
	if !logger.HasMessage("INFO", "Role was created by another instance") {
		t.Error("Should log info about role being created by another instance")
	}
}

func TestRoleManager_GetOrCreateRole_DoubleCheckAfterLock(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewMemoryLockManager(lock.DefaultLockConfig())
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-double-check"
	roleName := "DoubleCheckRole"

	// Start role creation in goroutine
	go func() {
		time.Sleep(20 * time.Millisecond)
		// Add role while the main thread might be acquiring lock
		session.AddRole(guildID, &discordgo.Role{
			ID:   "double-check-456",
			Name: roleName,
		})
	}()

	// Should either create new role or find the one created by goroutine
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() failed: %v", err)
	}

	if role == nil {
		t.Fatal("GetOrCreateRole() returned nil role")
	}

	if role.Name != roleName {
		t.Errorf("Role Name = %s, want %s", role.Name, roleName)
	}

	// Should have either creation or existing role message
	hasCreatedMsg := logger.HasMessage("INFO", "Created new Discord role")
	hasExistingMsg := logger.HasMessage("INFO", "Role already exists after acquiring lock")

	if !hasCreatedMsg && !hasExistingMsg {
		t.Error("Should log either creation or existing role message")
	}
}

func TestRoleManager_CreateRole_DefaultColor(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-color"
	roleName := "ColorRole"

	// Should use default color when nil provided
	_, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() failed: %v", err)
	}

	// Verify default color was used
	roles, err := session.GuildRoles(guildID)
	if err != nil {
		t.Fatalf("Failed to get roles: %v", err)
	}

	found := false
	for _, r := range roles {
		if r.Name == roleName && r.Color == 7506394 { // Default color
			found = true
			break
		}
	}

	if !found {
		t.Error("Role was not created with default color")
	}
}

func TestRoleManager_CreateRole_DiscordError(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	// Set up Discord error
	expectedErr := errors.New("Discord API error")
	session.SetRoleCreateError(expectedErr)

	guildID := "test-guild-error"
	roleName := "ErrorRole"

	// Should return Discord error
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err == nil {
		t.Fatal("GetOrCreateRole() should fail when Discord returns error")
	}

	if role != nil {
		t.Error("GetOrCreateRole() should return nil role on error")
	}

	if !contains(err.Error(), "failed to create Discord role") {
		t.Errorf("Error should mention Discord role creation failure, got: %v", err)
	}
}

func TestRoleManager_DeleteRole(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-delete"
	roleID := "role-to-delete"

	// Add role first
	session.AddRole(guildID, &discordgo.Role{
		ID:   roleID,
		Name: "DeleteMe",
	})

	// Should successfully delete role
	err := rm.DeleteRole(guildID, roleID)
	if err != nil {
		t.Errorf("DeleteRole() failed: %v", err)
	}

	// Should log info about deletion
	if !logger.HasMessage("INFO", "Deleted Discord role") {
		t.Error("Should log info about role deletion")
	}

	// Verify role was deleted
	roles, err := session.GuildRoles(guildID)
	if err != nil {
		t.Fatalf("Failed to get roles: %v", err)
	}

	for _, role := range roles {
		if role.ID == roleID {
			t.Error("Role should have been deleted")
		}
	}
}

func TestRoleManager_DeleteRole_Error(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	// Set up Discord delete error
	expectedErr := errors.New("Delete permission denied")
	session.SetRoleDeleteError(expectedErr)

	guildID := "test-guild-delete-error"
	roleID := "role-delete-error"

	// Should return Discord error
	err := rm.DeleteRole(guildID, roleID)
	if err == nil {
		t.Fatal("DeleteRole() should fail when Discord returns error")
	}

	if !contains(err.Error(), "failed to delete Discord role") {
		t.Errorf("Error should mention Discord role deletion failure, got: %v", err)
	}
}

func TestRoleManager_GetRoleByName_CaseInsensitive(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-case"

	// Add role with mixed case
	session.AddRole(guildID, &discordgo.Role{
		ID:   "case-role-123",
		Name: "VeriFieD",
	})

	// Should find role with different case
	role, err := rm.GetOrCreateRole(guildID, "VERIFIED", nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() failed: %v", err)
	}

	if role.ID != "case-role-123" {
		t.Error("Should find role with case-insensitive matching")
	}
}

func TestRoleManager_GetRoleByName_GuildRolesError_WithLocking(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewMemoryLockManager(lock.DefaultLockConfig())
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	// Set up GuildRoles error - this will affect both initial check and double-check
	expectedErr := errors.New("Guild not found")
	session.SetRolesError(expectedErr)

	guildID := "test-guild-roles-error"
	roleName := "TestRole"

	// Should succeed by creating the role, since GuildRoles error is ignored
	// in the double-check (if err == nil logic)
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() should succeed even when GuildRoles fails: %v", err)
	}

	if role == nil {
		t.Fatal("GetOrCreateRole() should return a role")
	}

	if role.Name != roleName {
		t.Errorf("Role name = %s, want %s", role.Name, roleName)
	}

	// Should log info about role creation since double-check failed
	if !logger.HasMessage("INFO", "Created new Discord role") {
		t.Error("Should log info about creating new role when double-check fails")
	}
}

func TestRoleManager_GetRoleByName_GuildRolesError_NoLocking(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewNoOpLockManager()
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	// Set up GuildRoles error - this will only affect the initial check
	expectedErr := errors.New("Guild not found")
	session.SetRolesError(expectedErr)

	guildID := "test-guild-roles-error-no-lock"
	roleName := "TestRole"

	// Without locking, it should still succeed by creating the role
	// (since GuildRoleCreate doesn't use GuildRoles)
	role, err := rm.GetOrCreateRole(guildID, roleName, nil)
	if err != nil {
		t.Fatalf("GetOrCreateRole() should succeed when only GuildRoles fails: %v", err)
	}

	if role == nil {
		t.Fatal("GetOrCreateRole() should return a role")
	}

	if role.Name != roleName {
		t.Errorf("Role name = %s, want %s", role.Name, roleName)
	}
}

func TestRoleManager_ConcurrentRoleCreation(t *testing.T) {
	session := NewMockDiscordSession()
	lockManager := lock.NewMemoryLockManager(lock.DefaultLockConfig())
	logger := NewMockLogger()
	rm := NewRoleManager(session, lockManager, logger)

	guildID := "test-guild-concurrent"
	roleName := "ConcurrentRole"
	numGoroutines := 10

	var wg sync.WaitGroup
	results := make([]*core.PlatformRole, numGoroutines)
	errors := make([]error, numGoroutines)

	// Launch multiple goroutines trying to create the same role
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			role, err := rm.GetOrCreateRole(guildID, roleName, nil)
			results[index] = role
			errors[index] = err
		}(i)
	}

	wg.Wait()

	// Check results
	successCount := 0
	var successRole *core.PlatformRole

	for i := 0; i < numGoroutines; i++ {
		if errors[i] == nil && results[i] != nil {
			successCount++
			if successRole == nil {
				successRole = results[i]
			} else {
				// All successful results should return the same role
				if results[i].ID != successRole.ID {
					t.Errorf("Different roles returned: %s vs %s", results[i].ID, successRole.ID)
				}
			}
		}
	}

	if successCount == 0 {
		t.Fatal("At least one goroutine should succeed")
	}

	// Verify only one role was actually created
	roles, err := session.GuildRoles(guildID)
	if err != nil {
		t.Fatalf("Failed to get roles: %v", err)
	}

	roleCount := 0
	for _, role := range roles {
		if role.Name == roleName {
			roleCount++
		}
	}

	if roleCount != 1 {
		t.Errorf("Expected exactly 1 role to be created, got %d", roleCount)
	}

	// Should have logged either creation or finding existing role
	hasCreated := logger.HasMessage("INFO", "Created new Discord role")
	hasFound := logger.HasMessage("DEBUG", "Found existing role") || 
		        logger.HasMessage("INFO", "Role already exists after acquiring lock")

	if !hasCreated && !hasFound {
		t.Error("Should log either role creation or finding existing role")
	}
}