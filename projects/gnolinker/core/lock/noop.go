package lock

import (
	"context"
	"time"
)

// NoOpLockManager implements a no-operation lock manager that always succeeds
// This is useful for single-instance deployments or when locking is disabled
type NoOpLockManager struct{}

// NewNoOpLockManager creates a new no-operation lock manager
func NewNoOpLockManager() *NoOpLockManager {
	return &NoOpLockManager{}
}

// AcquireLock always succeeds immediately
func (m *NoOpLockManager) AcquireLock(ctx context.Context, key string, ttl time.Duration) (*Lock, error) {
	now := time.Now()
	return &Lock{
		Key:        key,
		HolderID:   "noop",
		AcquiredAt: now,
		ExpiresAt:  now.Add(ttl),
		Token:      "noop-token",
	}, nil
}

// ReleaseLock always succeeds
func (m *NoOpLockManager) ReleaseLock(ctx context.Context, lock *Lock) error {
	return nil
}

// IsLocked always returns false (no locks exist)
func (m *NoOpLockManager) IsLocked(ctx context.Context, key string) (bool, error) {
	return false, nil
}

// GetLock always returns not found
func (m *NoOpLockManager) GetLock(ctx context.Context, key string) (*Lock, error) {
	return nil, ErrLockNotFound
}