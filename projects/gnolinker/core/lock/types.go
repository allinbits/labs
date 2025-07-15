package lock

import (
	"context"
	"errors"
	"time"
)

// Common errors
var (
	ErrLockAcquisitionFailed = errors.New("failed to acquire lock")
	ErrLockNotFound          = errors.New("lock not found")
	ErrLockExpired           = errors.New("lock has expired")
	ErrLockNotHeld           = errors.New("lock not held by this instance")
)

// LockManager provides distributed locking capabilities
type LockManager interface {
	// AcquireLock attempts to acquire a distributed lock with the given key and TTL
	// Returns a Lock object if successful, or an error if the lock could not be acquired
	AcquireLock(ctx context.Context, key string, ttl time.Duration) (*Lock, error)

	// ReleaseLock releases a previously acquired lock
	// This is best-effort - locks will auto-expire based on TTL
	ReleaseLock(ctx context.Context, lock *Lock) error

	// IsLocked checks if a lock exists and is still valid (not expired)
	IsLocked(ctx context.Context, key string) (bool, error)

	// GetLock retrieves information about an existing lock
	GetLock(ctx context.Context, key string) (*Lock, error)
}

// Lock represents a distributed lock
type Lock struct {
	Key        string    `json:"key"`
	HolderID   string    `json:"holder_id"`   // Unique identifier of the lock holder
	AcquiredAt time.Time `json:"acquired_at"`
	ExpiresAt  time.Time `json:"expires_at"`
	Token      string    `json:"token"` // Random token for additional verification
	Metadata   string    `json:"metadata,omitempty"` // Optional metadata about the lock purpose
}

// IsExpired checks if the lock has expired
func (l *Lock) IsExpired() bool {
	return time.Now().After(l.ExpiresAt)
}

// RemainingTTL returns the remaining time until the lock expires
func (l *Lock) RemainingTTL() time.Duration {
	remaining := time.Until(l.ExpiresAt)
	if remaining < 0 {
		return 0
	}
	return remaining
}

// LockConfig holds configuration for lock managers
type LockConfig struct {
	// Common configuration
	DefaultTTL    time.Duration
	RetryInterval time.Duration
	MaxRetries    int

	// Instance ID for this bot instance (auto-generated if not provided)
	InstanceID string
}

// DefaultLockConfig returns sensible defaults
func DefaultLockConfig() LockConfig {
	return LockConfig{
		DefaultTTL:    30 * time.Second,
		RetryInterval: 100 * time.Millisecond,
		MaxRetries:    10,
	}
}