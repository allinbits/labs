package storage

import (
	"errors"
	"fmt"
	"sync"
	"testing"
)

func TestNewMemoryConfigStore(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()

	if store == nil {
		t.Fatal("NewMemoryConfigStore() returned nil")
	}

	// Should be able to create multiple instances
	store2 := NewMemoryConfigStore()
	if store2 == nil {
		t.Fatal("NewMemoryConfigStore() second instance returned nil")
	}

	// They should be different instances
	if store == store2 {
		t.Error("NewMemoryConfigStore() should return different instances")
	}
}

func TestMemoryConfigStore_SetAndGet(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()
	guildID := "test-guild-123"

	// Create a test config
	config := NewGuildConfig(guildID)
	config.AdminRoleID = "admin-456"
	config.VerifiedRoleID = "verified-789"
	config.SetString("test_key", "test_value")

	// Set the config
	err := store.Set(guildID, config)
	if err != nil {
		t.Fatalf("Set() failed: %v", err)
	}

	// Get the config back
	retrieved, err := store.Get(guildID)
	if err != nil {
		t.Fatalf("Get() failed: %v", err)
	}

	// Verify the data
	if retrieved.GuildID != guildID {
		t.Errorf("GuildID = %q, want %q", retrieved.GuildID, guildID)
	}

	if retrieved.AdminRoleID != config.AdminRoleID {
		t.Errorf("AdminRoleID = %q, want %q", retrieved.AdminRoleID, config.AdminRoleID)
	}

	if retrieved.VerifiedRoleID != config.VerifiedRoleID {
		t.Errorf("VerifiedRoleID = %q, want %q", retrieved.VerifiedRoleID, config.VerifiedRoleID)
	}

	if retrieved.GetString("test_key", "") != "test_value" {
		t.Error("Settings not preserved correctly")
	}
}

func TestMemoryConfigStore_GetNotFound(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()

	// Try to get a config that doesn't exist
	_, err := store.Get("nonexistent-guild")
	
	if err == nil {
		t.Fatal("Get() should return error for nonexistent guild")
	}

	if !errors.Is(err, ErrGuildConfigNotFound) {
		t.Errorf("Get() error = %v, want %v", err, ErrGuildConfigNotFound)
	}
}

func TestMemoryConfigStore_Update(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()
	guildID := "test-guild-456"

	// Create initial config
	config1 := NewGuildConfig(guildID)
	config1.AdminRoleID = "admin-111"
	config1.SetString("version", "1")

	err := store.Set(guildID, config1)
	if err != nil {
		t.Fatalf("Initial Set() failed: %v", err)
	}

	// Update the config
	config2 := NewGuildConfig(guildID)
	config2.AdminRoleID = "admin-222"
	config2.VerifiedRoleID = "verified-333"
	config2.SetString("version", "2")

	err = store.Set(guildID, config2)
	if err != nil {
		t.Fatalf("Update Set() failed: %v", err)
	}

	// Verify the update
	retrieved, err := store.Get(guildID)
	if err != nil {
		t.Fatalf("Get() after update failed: %v", err)
	}

	if retrieved.AdminRoleID != "admin-222" {
		t.Errorf("AdminRoleID after update = %q, want %q", retrieved.AdminRoleID, "admin-222")
	}

	if retrieved.VerifiedRoleID != "verified-333" {
		t.Errorf("VerifiedRoleID after update = %q, want %q", retrieved.VerifiedRoleID, "verified-333")
	}

	if retrieved.GetString("version", "") != "2" {
		t.Error("Settings not updated correctly")
	}
}

func TestMemoryConfigStore_Delete(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()
	guildID := "test-guild-789"

	// Create and set a config
	config := NewGuildConfig(guildID)
	err := store.Set(guildID, config)
	if err != nil {
		t.Fatalf("Set() failed: %v", err)
	}

	// Verify it exists
	_, err = store.Get(guildID)
	if err != nil {
		t.Fatalf("Get() before delete failed: %v", err)
	}

	// Delete the config
	err = store.Delete(guildID)
	if err != nil {
		t.Fatalf("Delete() failed: %v", err)
	}

	// Verify it's gone
	_, err = store.Get(guildID)
	if err == nil {
		t.Fatal("Get() after delete should return error")
	}

	if !errors.Is(err, ErrGuildConfigNotFound) {
		t.Errorf("Get() after delete error = %v, want %v", err, ErrGuildConfigNotFound)
	}
}

func TestMemoryConfigStore_DeleteNonexistent(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()

	// Try to delete a config that doesn't exist
	err := store.Delete("nonexistent-guild")
	if err != nil {
		t.Errorf("Delete() of nonexistent guild should not return error, got: %v", err)
	}
}

func TestMemoryConfigStore_SetNilConfig(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()

	// Try to set a nil config
	err := store.Set("test-guild", nil)
	if err == nil {
		t.Fatal("Set() with nil config should return error")
	}

	expectedMsg := "config cannot be nil"
	if err.Error() != expectedMsg {
		t.Errorf("Set() nil error = %q, want %q", err.Error(), expectedMsg)
	}
}

func TestMemoryConfigStore_MultipleGuilds(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()

	// Create configs for multiple guilds
	guilds := []string{"guild-1", "guild-2", "guild-3"}
	
	for i, guildID := range guilds {
		config := NewGuildConfig(guildID)
		config.AdminRoleID = fmt.Sprintf("admin-%d", i+1)
		config.SetString("guild_number", fmt.Sprintf("%d", i+1))

		err := store.Set(guildID, config)
		if err != nil {
			t.Fatalf("Set() for guild %s failed: %v", guildID, err)
		}
	}

	// Verify all guilds exist and have correct data
	for i, guildID := range guilds {
		config, err := store.Get(guildID)
		if err != nil {
			t.Fatalf("Get() for guild %s failed: %v", guildID, err)
		}

		expectedAdminID := fmt.Sprintf("admin-%d", i+1)
		if config.AdminRoleID != expectedAdminID {
			t.Errorf("Guild %s AdminRoleID = %q, want %q", guildID, config.AdminRoleID, expectedAdminID)
		}

		expectedNumber := fmt.Sprintf("%d", i+1)
		if config.GetString("guild_number", "") != expectedNumber {
			t.Errorf("Guild %s guild_number = %q, want %q", guildID, config.GetString("guild_number", ""), expectedNumber)
		}
	}

	// Delete one guild and verify others remain
	err := store.Delete("guild-2")
	if err != nil {
		t.Fatalf("Delete() guild-2 failed: %v", err)
	}

	// guild-2 should be gone
	_, err = store.Get("guild-2")
	if err == nil {
		t.Error("guild-2 should be deleted")
	}

	// Others should still exist
	for _, guildID := range []string{"guild-1", "guild-3"} {
		_, err = store.Get(guildID)
		if err != nil {
			t.Errorf("Guild %s should still exist after deleting guild-2", guildID)
		}
	}
}

// Concurrent testing
func TestMemoryConfigStore_ConcurrentWrites(t *testing.T) {
	store := NewMemoryConfigStore()
	numGoroutines := 50
	numGuilds := 20

	var wg sync.WaitGroup
	wg.Add(numGoroutines)

	// Launch multiple goroutines writing to different guilds
	for i := 0; i < numGoroutines; i++ {
		go func(workerID int) {
			defer wg.Done()

			for j := 0; j < numGuilds; j++ {
				guildID := fmt.Sprintf("guild-%d-%d", workerID, j)
				config := NewGuildConfig(guildID)
				config.AdminRoleID = fmt.Sprintf("admin-%d-%d", workerID, j)
				config.SetString("worker_id", fmt.Sprintf("%d", workerID))
				config.SetString("guild_num", fmt.Sprintf("%d", j))

				err := store.Set(guildID, config)
				if err != nil {
					t.Errorf("Worker %d: Set() failed for guild %s: %v", workerID, guildID, err)
				}
			}
		}(i)
	}

	wg.Wait()

	// Verify all data was written correctly
	for i := 0; i < numGoroutines; i++ {
		for j := 0; j < numGuilds; j++ {
			guildID := fmt.Sprintf("guild-%d-%d", i, j)
			config, err := store.Get(guildID)
			if err != nil {
				t.Errorf("Get() failed for guild %s: %v", guildID, err)
				continue
			}

			expectedAdminID := fmt.Sprintf("admin-%d-%d", i, j)
			if config.AdminRoleID != expectedAdminID {
				t.Errorf("Guild %s AdminRoleID = %q, want %q", guildID, config.AdminRoleID, expectedAdminID)
			}

			if config.GetString("worker_id", "") != fmt.Sprintf("%d", i) {
				t.Errorf("Guild %s worker_id incorrect", guildID)
			}
		}
	}
}

func TestMemoryConfigStore_ConcurrentReadWrites(t *testing.T) {
	store := NewMemoryConfigStore()
	guildID := "shared-guild"

	// Initialize the guild
	initialConfig := NewGuildConfig(guildID)
	initialConfig.SetString("counter", "0")
	err := store.Set(guildID, initialConfig)
	if err != nil {
		t.Fatalf("Initial Set() failed: %v", err)
	}

	numReaders := 10
	numWriters := 5
	numOperations := 20

	var wg sync.WaitGroup
	wg.Add(numReaders + numWriters)

	// Launch readers
	for i := 0; i < numReaders; i++ {
		go func(readerID int) {
			defer wg.Done()

			for j := 0; j < numOperations; j++ {
				_, err := store.Get(guildID)
				if err != nil {
					t.Errorf("Reader %d: Get() failed: %v", readerID, err)
				}
			}
		}(i)
	}

	// Launch writers
	for i := 0; i < numWriters; i++ {
		go func(writerID int) {
			defer wg.Done()

			for j := 0; j < numOperations; j++ {
				config := NewGuildConfig(guildID)
				config.SetString("writer", fmt.Sprintf("%d", writerID))
				config.SetString("operation", fmt.Sprintf("%d", j))

				err := store.Set(guildID, config)
				if err != nil {
					t.Errorf("Writer %d: Set() failed: %v", writerID, err)
				}
			}
		}(i)
	}

	wg.Wait()

	// Verify final state is readable
	finalConfig, err := store.Get(guildID)
	if err != nil {
		t.Fatalf("Final Get() failed: %v", err)
	}

	if finalConfig.GuildID != guildID {
		t.Errorf("Final config GuildID = %q, want %q", finalConfig.GuildID, guildID)
	}
}

func TestMemoryConfigStore_ConcurrentDeletes(t *testing.T) {
	store := NewMemoryConfigStore()
	numGoroutines := 20
	guildID := "delete-test-guild"

	// Create the guild first
	config := NewGuildConfig(guildID)
	err := store.Set(guildID, config)
	if err != nil {
		t.Fatalf("Initial Set() failed: %v", err)
	}

	var wg sync.WaitGroup
	wg.Add(numGoroutines)

	// Launch multiple goroutines trying to delete the same guild
	deleteSuccesses := make(chan bool, numGoroutines)

	for i := 0; i < numGoroutines; i++ {
		go func() {
			defer wg.Done()

			err := store.Delete(guildID)
			deleteSuccesses <- (err == nil)
		}()
	}

	wg.Wait()
	close(deleteSuccesses)

	// All deletes should succeed (idempotent)
	successCount := 0
	for success := range deleteSuccesses {
		if success {
			successCount++
		}
	}

	if successCount != numGoroutines {
		t.Errorf("Expected all %d deletes to succeed, got %d", numGoroutines, successCount)
	}

	// Guild should be gone
	_, err = store.Get(guildID)
	if err == nil {
		t.Error("Guild should be deleted")
	}
}

func TestMemoryConfigStore_DataIsolation(t *testing.T) {
	t.Parallel()
	store := NewMemoryConfigStore()
	guildID := "isolation-test"

	// Set initial config
	config1 := NewGuildConfig(guildID)
	config1.AdminRoleID = "admin-123"
	config1.SetString("test", "original")

	err := store.Set(guildID, config1)
	if err != nil {
		t.Fatalf("Set() failed: %v", err)
	}

	// Get the config
	retrieved, err := store.Get(guildID)
	if err != nil {
		t.Fatalf("Get() failed: %v", err)
	}

	// Modify the retrieved config
	retrieved.AdminRoleID = "modified-admin"
	retrieved.SetString("test", "modified")

	// Get the config again - should be unchanged
	retrieved2, err := store.Get(guildID)
	if err != nil {
		t.Fatalf("Second Get() failed: %v", err)
	}

	if retrieved2.AdminRoleID != "admin-123" {
		t.Errorf("AdminRoleID was modified externally: %q, want %q", retrieved2.AdminRoleID, "admin-123")
	}

	if retrieved2.GetString("test", "") != "original" {
		t.Error("Settings were modified externally")
	}
}