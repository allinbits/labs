package lock

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"
)

func TestNewMemoryLockManager(t *testing.T) {
	tests := []struct {
		name   string
		config LockConfig
	}{
		{
			name: "default config",
			config: LockConfig{
				DefaultTTL:    30 * time.Second,
				RetryInterval: 100 * time.Millisecond,
				MaxRetries:    10,
			},
		},
		{
			name: "custom config",
			config: LockConfig{
				DefaultTTL:    time.Minute,
				RetryInterval: 250 * time.Millisecond,
				MaxRetries:    5,
				InstanceID:    "test-instance",
			},
		},
		{
			name:   "empty config",
			config: LockConfig{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager := NewMemoryLockManager(tt.config)

			if manager == nil {
				t.Fatal("NewMemoryLockManager() returned nil")
			}

			// Instance ID should be set
			if manager.instanceID == "" {
				t.Error("InstanceID should not be empty")
			}

			// If we provided an instance ID, it should be used
			if tt.config.InstanceID != "" && manager.instanceID != tt.config.InstanceID {
				t.Errorf("InstanceID = %q, want %q", manager.instanceID, tt.config.InstanceID)
			}

			// Default TTL should be set
			if manager.config.DefaultTTL == 0 {
				t.Error("DefaultTTL should not be zero")
			}
		})
	}
}

func TestMemoryLockManager_AcquireLock(t *testing.T) {
	manager := NewMemoryLockManager(LockConfig{
		DefaultTTL:    30 * time.Second,
		RetryInterval: 10 * time.Millisecond,
		MaxRetries:    2,
	})

	ctx := context.Background()

	tests := []struct {
		name string
		key  string
		ttl  time.Duration
	}{
		{
			name: "basic lock",
			key:  "test-key",
			ttl:  time.Minute,
		},
		{
			name: "zero ttl uses default",
			key:  "zero-ttl-key",
			ttl:  0,
		},
		{
			name: "long ttl",
			key:  "long-key",
			ttl:  24 * time.Hour,
		},
		{
			name: "empty key",
			key:  "",
			ttl:  time.Minute,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lock, err := manager.AcquireLock(ctx, tt.key, tt.ttl)

			if err != nil {
				t.Errorf("AcquireLock() failed: %v", err)
			}

			if lock == nil {
				t.Fatal("AcquireLock() returned nil lock")
			}

			if lock.Key != tt.key {
				t.Errorf("Lock.Key = %q, want %q", lock.Key, tt.key)
			}

			if lock.HolderID != manager.instanceID {
				t.Errorf("Lock.HolderID = %q, want %q", lock.HolderID, manager.instanceID)
			}

			if lock.Token == "" {
				t.Error("Lock.Token should not be empty")
			}

			if lock.AcquiredAt.IsZero() {
				t.Error("Lock.AcquiredAt should not be zero")
			}

			if lock.ExpiresAt.IsZero() {
				t.Error("Lock.ExpiresAt should not be zero")
			}

			// Should not be expired immediately
			if lock.IsExpired() {
				t.Error("Lock should not be expired immediately")
			}

			// Clean up
			manager.ReleaseLock(ctx, lock)
		})
	}
}

func TestMemoryLockManager_AcquireLockConflict(t *testing.T) {
	manager := NewMemoryLockManager(LockConfig{
		DefaultTTL:    30 * time.Second,
		RetryInterval: 10 * time.Millisecond,
		MaxRetries:    1,
	})

	ctx := context.Background()
	key := "conflict-key"

	// Acquire first lock
	lock1, err := manager.AcquireLock(ctx, key, time.Minute)
	if err != nil {
		t.Fatalf("First AcquireLock() failed: %v", err)
	}

	// Try to acquire same key - should fail
	lock2, err := manager.AcquireLock(ctx, key, time.Minute)
	if err == nil {
		t.Error("Second AcquireLock() should fail")
	}

	if lock2 != nil {
		t.Error("Second AcquireLock() should return nil lock")
	}

	if err != ErrLockAcquisitionFailed {
		t.Errorf("AcquireLock() error = %v, want %v", err, ErrLockAcquisitionFailed)
	}

	// Release first lock
	err = manager.ReleaseLock(ctx, lock1)
	if err != nil {
		t.Errorf("ReleaseLock() failed: %v", err)
	}

	// Now should be able to acquire
	lock3, err := manager.AcquireLock(ctx, key, time.Minute)
	if err != nil {
		t.Errorf("Third AcquireLock() failed: %v", err)
	}

	if lock3 == nil {
		t.Error("Third AcquireLock() should succeed")
	}
}

func TestMemoryLockManager_ReleaseLock(t *testing.T) {
	manager := NewMemoryLockManager(DefaultLockConfig())
	ctx := context.Background()

	// Test releasing a valid lock
	lock, err := manager.AcquireLock(ctx, "test-key", time.Minute)
	if err != nil {
		t.Fatalf("AcquireLock() failed: %v", err)
	}

	err = manager.ReleaseLock(ctx, lock)
	if err != nil {
		t.Errorf("ReleaseLock() failed: %v", err)
	}

	// Should be able to acquire again
	lock2, err := manager.AcquireLock(ctx, "test-key", time.Minute)
	if err != nil {
		t.Errorf("AcquireLock() after release failed: %v", err)
	}

	if lock2 == nil {
		t.Error("Should be able to acquire after release")
	}

	// Test releasing nil lock
	err = manager.ReleaseLock(ctx, nil)
	if err == nil {
		t.Error("ReleaseLock() with nil should fail")
	}

	// Test releasing non-existent lock
	fakeLock := &Lock{
		Key:        "fake-key",
		HolderID:   manager.instanceID,
		AcquiredAt: time.Now(),
		ExpiresAt:  time.Now().Add(time.Minute),
		Token:      "fake-token",
	}

	err = manager.ReleaseLock(ctx, fakeLock)
	if err != ErrLockNotFound {
		t.Errorf("ReleaseLock() with fake lock error = %v, want %v", err, ErrLockNotFound)
	}

	// Test releasing lock held by different instance
	wrongHolderLock := &Lock{
		Key:        lock2.Key,
		HolderID:   "wrong-holder",
		AcquiredAt: lock2.AcquiredAt,
		ExpiresAt:  lock2.ExpiresAt,
		Token:      lock2.Token,
	}

	err = manager.ReleaseLock(ctx, wrongHolderLock)
	if err != ErrLockNotHeld {
		t.Errorf("ReleaseLock() with wrong holder error = %v, want %v", err, ErrLockNotHeld)
	}

	// Clean up
	manager.ReleaseLock(ctx, lock2)
}

func TestMemoryLockManager_IsLocked(t *testing.T) {
	manager := NewMemoryLockManager(DefaultLockConfig())
	ctx := context.Background()
	key := "test-key"

	// Initially should not be locked
	locked, err := manager.IsLocked(ctx, key)
	if err != nil {
		t.Errorf("IsLocked() failed: %v", err)
	}

	if locked {
		t.Error("Key should not be locked initially")
	}

	// Acquire lock
	lock, err := manager.AcquireLock(ctx, key, time.Minute)
	if err != nil {
		t.Fatalf("AcquireLock() failed: %v", err)
	}

	// Should be locked now
	locked, err = manager.IsLocked(ctx, key)
	if err != nil {
		t.Errorf("IsLocked() after acquire failed: %v", err)
	}

	if !locked {
		t.Error("Key should be locked after acquire")
	}

	// Release lock
	err = manager.ReleaseLock(ctx, lock)
	if err != nil {
		t.Errorf("ReleaseLock() failed: %v", err)
	}

	// Should not be locked after release
	locked, err = manager.IsLocked(ctx, key)
	if err != nil {
		t.Errorf("IsLocked() after release failed: %v", err)
	}

	if locked {
		t.Error("Key should not be locked after release")
	}
}

func TestMemoryLockManager_GetLock(t *testing.T) {
	manager := NewMemoryLockManager(DefaultLockConfig())
	ctx := context.Background()
	key := "test-key"

	// Initially should return not found
	_, err := manager.GetLock(ctx, key)
	if err != ErrLockNotFound {
		t.Errorf("GetLock() for non-existent key error = %v, want %v", err, ErrLockNotFound)
	}

	// Acquire lock
	lock, err := manager.AcquireLock(ctx, key, time.Minute)
	if err != nil {
		t.Fatalf("AcquireLock() failed: %v", err)
	}

	// Get lock info
	retrieved, err := manager.GetLock(ctx, key)
	if err != nil {
		t.Errorf("GetLock() failed: %v", err)
	}

	if retrieved == nil {
		t.Fatal("GetLock() returned nil lock")
	}

	// Verify lock data
	if retrieved.Key != lock.Key {
		t.Errorf("Retrieved Key = %q, want %q", retrieved.Key, lock.Key)
	}

	if retrieved.HolderID != lock.HolderID {
		t.Errorf("Retrieved HolderID = %q, want %q", retrieved.HolderID, lock.HolderID)
	}

	if retrieved.Token != lock.Token {
		t.Errorf("Retrieved Token = %q, want %q", retrieved.Token, lock.Token)
	}

	// Verify it's a copy (modifying shouldn't affect original)
	retrieved.Token = "modified"
	
	retrieved2, err := manager.GetLock(ctx, key)
	if err != nil {
		t.Errorf("Second GetLock() failed: %v", err)
	}

	if retrieved2.Token == "modified" {
		t.Error("GetLock() should return a copy, not the original")
	}

	// Clean up
	manager.ReleaseLock(ctx, lock)
}

func TestMemoryLockManager_ExpiredLocks(t *testing.T) {
	manager := NewMemoryLockManager(LockConfig{
		DefaultTTL:    10 * time.Millisecond,
		RetryInterval: 5 * time.Millisecond,
		MaxRetries:    2,
	})

	ctx := context.Background()
	key := "expired-key"

	// Acquire lock with short TTL
	lock, err := manager.AcquireLock(ctx, key, 10*time.Millisecond)
	if err != nil {
		t.Fatalf("AcquireLock() failed: %v", err)
	}
	_ = lock

	// Should be locked initially
	locked, err := manager.IsLocked(ctx, key)
	if err != nil {
		t.Errorf("IsLocked() failed: %v", err)
	}

	if !locked {
		t.Error("Key should be locked")
	}

	// Wait for expiration
	time.Sleep(20 * time.Millisecond)

	// Should not be locked after expiration
	locked, err = manager.IsLocked(ctx, key)
	if err != nil {
		t.Errorf("IsLocked() after expiration failed: %v", err)
	}

	if locked {
		t.Error("Key should not be locked after expiration")
	}

	// Should be able to acquire again (expired lock is treated as non-existent)
	lock2, err := manager.AcquireLock(ctx, key, time.Minute)
	if err != nil {
		t.Errorf("AcquireLock() after expiration failed: %v", err)
	}

	if lock2 == nil {
		t.Error("Should be able to acquire expired lock")
	}

	// Clean up
	manager.ReleaseLock(ctx, lock2)
}

func TestMemoryLockManager_CleanupExpiredLocks(t *testing.T) {
	manager := NewMemoryLockManager(DefaultLockConfig())
	ctx := context.Background()

	// Acquire several locks with short TTL
	keys := []string{"key1", "key2", "key3"}
	for _, key := range keys {
		_, err := manager.AcquireLock(ctx, key, 10*time.Millisecond)
		if err != nil {
			t.Fatalf("AcquireLock() for %s failed: %v", key, err)
		}
	}

	// Wait for expiration
	time.Sleep(20 * time.Millisecond)

	// Before cleanup - expired locks should still exist in memory
	manager.mu.RLock()
	lockCount := len(manager.locks)
	manager.mu.RUnlock()

	if lockCount != 3 {
		t.Errorf("Expected 3 locks in memory before cleanup, got %d", lockCount)
	}

	// Run cleanup
	manager.CleanupExpiredLocks()

	// After cleanup - expired locks should be removed
	manager.mu.RLock()
	lockCount = len(manager.locks)
	manager.mu.RUnlock()

	if lockCount != 0 {
		t.Errorf("Expected 0 locks in memory after cleanup, got %d", lockCount)
	}
}

func TestMemoryLockManager_StartCleanupTask(t *testing.T) {
	manager := NewMemoryLockManager(DefaultLockConfig())
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Acquire lock with short TTL
	lock, err := manager.AcquireLock(ctx, "cleanup-test", 20*time.Millisecond)
	if err != nil {
		t.Fatalf("AcquireLock() failed: %v", err)
	}
	_ = lock

	// Start cleanup task with short interval
	manager.StartCleanupTask(ctx, 30*time.Millisecond)

	// Wait for lock to expire and cleanup to run
	time.Sleep(60 * time.Millisecond)

	// Check that lock was cleaned up
	manager.mu.RLock()
	lockCount := len(manager.locks)
	manager.mu.RUnlock()

	if lockCount > 0 {
		t.Errorf("Expected lock to be cleaned up automatically, but %d locks remain", lockCount)
	}
}

func TestMemoryLockManager_ContextCancellation(t *testing.T) {
	manager := NewMemoryLockManager(LockConfig{
		DefaultTTL:    30 * time.Second,
		RetryInterval: 50 * time.Millisecond,
		MaxRetries:    10,
	})

	// Acquire a lock first
	bgCtx := context.Background()
	_, err := manager.AcquireLock(bgCtx, "blocked-key", time.Minute)
	if err != nil {
		t.Fatalf("AcquireLock() setup failed: %v", err)
	}

	// Try to acquire same key with cancelled context
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	lock, err := manager.AcquireLock(ctx, "blocked-key", time.Minute)
	if err != context.Canceled {
		t.Errorf("AcquireLock() with cancelled context error = %v, want %v", err, context.Canceled)
	}

	if lock != nil {
		t.Error("AcquireLock() with cancelled context should return nil lock")
	}
}

func TestMemoryLockManager_ConcurrentAcquire(t *testing.T) {
	manager := NewMemoryLockManager(LockConfig{
		DefaultTTL:    30 * time.Second,
		RetryInterval: 10 * time.Millisecond,
		MaxRetries:    5,
	})

	ctx := context.Background()
	numGoroutines := 10
	key := "concurrent-key"

	var wg sync.WaitGroup
	successes := make(chan *Lock, numGoroutines)
	failures := make(chan error, numGoroutines)

	// Launch multiple goroutines trying to acquire the same lock
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			
			lock, err := manager.AcquireLock(ctx, key, time.Minute)
			if err != nil {
				failures <- err
			} else {
				successes <- lock
			}
		}(i)
	}

	wg.Wait()
	close(successes)
	close(failures)

	// Count results
	successCount := 0
	failureCount := 0
	var winningLock *Lock

	for lock := range successes {
		successCount++
		winningLock = lock
	}

	for range failures {
		failureCount++
	}

	// Exactly one should succeed
	if successCount != 1 {
		t.Errorf("Expected exactly 1 success, got %d", successCount)
	}

	if failureCount != numGoroutines-1 {
		t.Errorf("Expected %d failures, got %d", numGoroutines-1, failureCount)
	}

	// Clean up
	if winningLock != nil {
		manager.ReleaseLock(ctx, winningLock)
	}
}

func TestMemoryLockManager_ConcurrentDifferentKeys(t *testing.T) {
	manager := NewMemoryLockManager(DefaultLockConfig())
	ctx := context.Background()
	numGoroutines := 50

	var wg sync.WaitGroup
	errors := make(chan error, numGoroutines)

	// Launch goroutines acquiring different keys
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			
			key := fmt.Sprintf("key-%d", id)
			lock, err := manager.AcquireLock(ctx, key, time.Minute)
			if err != nil {
				errors <- err
				return
			}

			// Hold the lock briefly
			time.Sleep(time.Millisecond)

			// Release the lock
			err = manager.ReleaseLock(ctx, lock)
			if err != nil {
				errors <- err
			}
		}(i)
	}

	wg.Wait()
	close(errors)

	// No errors should occur
	errorCount := 0
	for err := range errors {
		t.Errorf("Unexpected error: %v", err)
		errorCount++
	}

	if errorCount > 0 {
		t.Errorf("Expected no errors for different keys, got %d", errorCount)
	}
}

func TestMemoryLockManager_Interface(t *testing.T) {
	// Verify that MemoryLockManager implements LockManager interface
	var _ LockManager = &MemoryLockManager{}
	var _ LockManager = NewMemoryLockManager(DefaultLockConfig())
}