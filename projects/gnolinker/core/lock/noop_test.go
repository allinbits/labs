package lock

import (
	"context"
	"fmt"
	"testing"
	"time"
)

func TestNewNoOpLockManager(t *testing.T) {
	manager := NewNoOpLockManager()
	
	if manager == nil {
		t.Fatal("NewNoOpLockManager() returned nil")
	}

	// Should be able to create multiple instances
	manager2 := NewNoOpLockManager()
	if manager2 == nil {
		t.Fatal("NewNoOpLockManager() second instance returned nil")
	}
}

func TestNoOpLockManager_AcquireLock(t *testing.T) {
	manager := NewNoOpLockManager()
	ctx := context.Background()

	tests := []struct {
		name string
		key  string
		ttl  time.Duration
	}{
		{
			name: "simple lock",
			key:  "test-key",
			ttl:  30 * time.Second,
		},
		{
			name: "zero ttl",
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
		{
			name: "special characters in key",
			key:  "test:key/with-special*chars",
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

			// Verify lock fields
			if lock.Key != tt.key {
				t.Errorf("Lock.Key = %q, want %q", lock.Key, tt.key)
			}

			if lock.HolderID != "noop" {
				t.Errorf("Lock.HolderID = %q, want %q", lock.HolderID, "noop")
			}

			if lock.Token != "noop-token" {
				t.Errorf("Lock.Token = %q, want %q", lock.Token, "noop-token")
			}

			// Verify times are reasonable
			if lock.AcquiredAt.IsZero() {
				t.Error("Lock.AcquiredAt should not be zero")
			}

			if lock.ExpiresAt.IsZero() {
				t.Error("Lock.ExpiresAt should not be zero")
			}

			// ExpiresAt should be after AcquiredAt for positive TTL
			if tt.ttl > 0 && !lock.ExpiresAt.After(lock.AcquiredAt) {
				t.Error("Lock.ExpiresAt should be after AcquiredAt for positive TTL")
			}

			// For zero TTL, ExpiresAt should equal AcquiredAt
			if tt.ttl == 0 && !lock.ExpiresAt.Equal(lock.AcquiredAt) {
				t.Error("Lock.ExpiresAt should equal AcquiredAt for zero TTL")
			}

			// Should not be expired immediately for positive TTL
			if tt.ttl > 0 && lock.IsExpired() {
				t.Error("Lock should not be expired immediately after acquisition")
			}
		})
	}
}

func TestNoOpLockManager_AcquireLockMultiple(t *testing.T) {
	manager := NewNoOpLockManager()
	ctx := context.Background()
	key := "shared-key"

	// NoOp manager should always succeed, even for same key
	locks := make([]*Lock, 5)
	for i := 0; i < 5; i++ {
		lock, err := manager.AcquireLock(ctx, key, time.Minute)
		if err != nil {
			t.Errorf("AcquireLock() %d failed: %v", i, err)
		}
		if lock == nil {
			t.Errorf("AcquireLock() %d returned nil lock", i)
		}
		locks[i] = lock
	}

	// All locks should have the same key but different acquisition times
	for i, lock := range locks {
		if lock.Key != key {
			t.Errorf("Lock %d Key = %q, want %q", i, lock.Key, key)
		}
	}
}

func TestNoOpLockManager_ReleaseLock(t *testing.T) {
	manager := NewNoOpLockManager()
	ctx := context.Background()

	// Test releasing a lock acquired from this manager
	lock, err := manager.AcquireLock(ctx, "test-key", time.Minute)
	if err != nil {
		t.Fatalf("AcquireLock() failed: %v", err)
	}

	err = manager.ReleaseLock(ctx, lock)
	if err != nil {
		t.Errorf("ReleaseLock() failed: %v", err)
	}

	// Test releasing a nil lock
	err = manager.ReleaseLock(ctx, nil)
	if err != nil {
		t.Errorf("ReleaseLock() with nil lock should not fail, got: %v", err)
	}

	// Test releasing a fake lock
	fakeLock := &Lock{
		Key:        "fake-key",
		HolderID:   "fake-holder",
		AcquiredAt: time.Now(),
		ExpiresAt:  time.Now().Add(time.Minute),
		Token:      "fake-token",
	}

	err = manager.ReleaseLock(ctx, fakeLock)
	if err != nil {
		t.Errorf("ReleaseLock() with fake lock should not fail, got: %v", err)
	}
}

func TestNoOpLockManager_IsLocked(t *testing.T) {
	manager := NewNoOpLockManager()
	ctx := context.Background()

	tests := []string{
		"test-key",
		"another-key",
		"",
		"key-with-special:chars/and*symbols",
	}

	for _, key := range tests {
		t.Run("key_"+key, func(t *testing.T) {
			locked, err := manager.IsLocked(ctx, key)
			
			if err != nil {
				t.Errorf("IsLocked() failed: %v", err)
			}

			if locked {
				t.Error("IsLocked() should always return false for NoOp manager")
			}
		})
	}
}

func TestNoOpLockManager_GetLock(t *testing.T) {
	manager := NewNoOpLockManager()
	ctx := context.Background()

	tests := []string{
		"test-key",
		"another-key",
		"",
		"any-key",
	}

	for _, key := range tests {
		t.Run("key_"+key, func(t *testing.T) {
			lock, err := manager.GetLock(ctx, key)
			
			if lock != nil {
				t.Error("GetLock() should always return nil lock for NoOp manager")
			}

			if err == nil {
				t.Error("GetLock() should always return error for NoOp manager")
			}

			if err != ErrLockNotFound {
				t.Errorf("GetLock() error = %v, want %v", err, ErrLockNotFound)
			}
		})
	}
}

func TestNoOpLockManager_ContextCancellation(t *testing.T) {
	manager := NewNoOpLockManager()

	// Test with cancelled context
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	// AcquireLock should still succeed (NoOp doesn't check context)
	lock, err := manager.AcquireLock(ctx, "test-key", time.Minute)
	if err != nil {
		t.Errorf("AcquireLock() with cancelled context failed: %v", err)
	}
	if lock == nil {
		t.Error("AcquireLock() with cancelled context returned nil lock")
	}

	// ReleaseLock should still succeed
	err = manager.ReleaseLock(ctx, lock)
	if err != nil {
		t.Errorf("ReleaseLock() with cancelled context failed: %v", err)
	}

	// IsLocked should still succeed
	locked, err := manager.IsLocked(ctx, "test-key")
	if err != nil {
		t.Errorf("IsLocked() with cancelled context failed: %v", err)
	}
	if locked {
		t.Error("IsLocked() should return false")
	}

	// GetLock should still return expected error
	retrievedLock, err := manager.GetLock(ctx, "test-key")
	if retrievedLock != nil {
		t.Error("GetLock() with cancelled context should return nil lock")
	}
	if err != ErrLockNotFound {
		t.Errorf("GetLock() with cancelled context error = %v, want %v", err, ErrLockNotFound)
	}
}

func TestNoOpLockManager_Timeout(t *testing.T) {
	manager := NewNoOpLockManager()

	// Test with timeout context
	ctx, cancel := context.WithTimeout(context.Background(), time.Millisecond)
	defer cancel()

	// Wait for timeout
	time.Sleep(10 * time.Millisecond)

	// Operations should still succeed (NoOp ignores timeouts)
	lock, err := manager.AcquireLock(ctx, "test-key", time.Minute)
	if err != nil {
		t.Errorf("AcquireLock() with timeout context failed: %v", err)
	}
	if lock == nil {
		t.Error("AcquireLock() with timeout context returned nil lock")
	}
}

func TestNoOpLockManager_Concurrent(t *testing.T) {
	manager := NewNoOpLockManager()
	ctx := context.Background()
	numGoroutines := 20
	numOperations := 10

	// Test concurrent operations
	for i := 0; i < numGoroutines; i++ {
		go func(workerID int) {
			for j := 0; j < numOperations; j++ {
				key := fmt.Sprintf("key-%d-%d", workerID, j)

				// Acquire lock
				lock, err := manager.AcquireLock(ctx, key, time.Minute)
				if err != nil {
					t.Errorf("Worker %d: AcquireLock() failed: %v", workerID, err)
					continue
				}

				// Check if locked (should be false)
				locked, err := manager.IsLocked(ctx, key)
				if err != nil {
					t.Errorf("Worker %d: IsLocked() failed: %v", workerID, err)
				}
				if locked {
					t.Errorf("Worker %d: IsLocked() should return false", workerID)
				}

				// Release lock
				err = manager.ReleaseLock(ctx, lock)
				if err != nil {
					t.Errorf("Worker %d: ReleaseLock() failed: %v", workerID, err)
				}
			}
		}(i)
	}
}

func TestNoOpLockManager_Interface(t *testing.T) {
	// Verify that NoOpLockManager implements LockManager interface
	var _ LockManager = &NoOpLockManager{}
	var _ LockManager = NewNoOpLockManager()
}