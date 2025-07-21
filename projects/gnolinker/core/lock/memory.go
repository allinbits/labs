package lock

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

// MemoryLockManager implements in-memory locking for single-instance deployments
type MemoryLockManager struct {
	mu         sync.RWMutex
	locks      map[string]*Lock
	instanceID string
	config     LockConfig
}

// NewMemoryLockManager creates a new in-memory lock manager
func NewMemoryLockManager(cfg LockConfig) *MemoryLockManager {
	if cfg.InstanceID == "" {
		cfg.InstanceID = uuid.New().String()
	}
	if cfg.DefaultTTL == 0 {
		cfg.DefaultTTL = 30 * time.Second
	}

	return &MemoryLockManager{
		locks:      make(map[string]*Lock),
		instanceID: cfg.InstanceID,
		config:     cfg,
	}
}

// AcquireLock attempts to acquire a lock
func (m *MemoryLockManager) AcquireLock(ctx context.Context, key string, ttl time.Duration) (*Lock, error) {
	if ttl == 0 {
		ttl = m.config.DefaultTTL
	}

	lock := &Lock{
		Key:        key,
		HolderID:   m.instanceID,
		AcquiredAt: time.Now(),
		ExpiresAt:  time.Now().Add(ttl),
		Token:      uuid.New().String(),
	}

	// Try to acquire lock with retries
	for i := 0; i <= m.config.MaxRetries; i++ {
		if i > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(m.config.RetryInterval):
			}
		}

		m.mu.Lock()
		existing, exists := m.locks[key]

		if !exists || existing.IsExpired() {
			// Lock doesn't exist or is expired, we can take it
			m.locks[key] = lock
			m.mu.Unlock()
			return lock, nil
		}
		m.mu.Unlock()
	}

	return nil, ErrLockAcquisitionFailed
}

// ReleaseLock releases a lock
func (m *MemoryLockManager) ReleaseLock(ctx context.Context, lock *Lock) error {
	if lock == nil {
		return errors.New("lock cannot be nil")
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	existing, exists := m.locks[lock.Key]
	if !exists {
		return ErrLockNotFound
	}

	if existing.HolderID != lock.HolderID || existing.Token != lock.Token {
		return ErrLockNotHeld
	}

	delete(m.locks, lock.Key)
	return nil
}

// IsLocked checks if a lock exists and is valid
func (m *MemoryLockManager) IsLocked(ctx context.Context, key string) (bool, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	lock, exists := m.locks[key]
	if !exists {
		return false, nil
	}

	return !lock.IsExpired(), nil
}

// GetLock retrieves information about a lock
func (m *MemoryLockManager) GetLock(ctx context.Context, key string) (*Lock, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	lock, exists := m.locks[key]
	if !exists {
		return nil, ErrLockNotFound
	}

	// Return a copy to prevent external modification
	lockCopy := *lock
	return &lockCopy, nil
}

// CleanupExpiredLocks removes expired locks
func (m *MemoryLockManager) CleanupExpiredLocks() {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now()
	for key, lock := range m.locks {
		if now.After(lock.ExpiresAt) {
			delete(m.locks, key)
		}
	}
}

// StartCleanupTask starts a background task to clean up expired locks
func (m *MemoryLockManager) StartCleanupTask(ctx context.Context, interval time.Duration) {
	if interval == 0 {
		interval = 5 * time.Minute
	}

	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				m.CleanupExpiredLocks()
			}
		}
	}()
}
