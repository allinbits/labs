package lock

import (
	"testing"
	"time"
)

func TestLock_IsExpired(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		expiresAt time.Time
		want      bool
	}{
		{
			name:      "expired lock",
			expiresAt: now.Add(-time.Minute), // 1 minute ago
			want:      true,
		},
		{
			name:      "not expired lock",
			expiresAt: now.Add(time.Minute), // 1 minute from now
			want:      false,
		},
		{
			name:      "just expired",
			expiresAt: now.Add(-time.Millisecond), // Just past
			want:      true,
		},
		{
			name:      "just not expired",
			expiresAt: now.Add(time.Millisecond), // Just future
			want:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lock := &Lock{
				Key:        "test-key",
				HolderID:   "test-holder",
				AcquiredAt: now.Add(-time.Hour),
				ExpiresAt:  tt.expiresAt,
				Token:      "test-token",
			}

			got := lock.IsExpired()
			if got != tt.want {
				t.Errorf("IsExpired() = %t, want %t", got, tt.want)
			}
		})
	}
}

func TestLock_RemainingTTL(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		expiresAt time.Time
		wantMin   time.Duration // Minimum expected (accounting for test execution time)
		wantMax   time.Duration // Maximum expected
	}{
		{
			name:      "expired lock",
			expiresAt: now.Add(-time.Minute),
			wantMin:   0,
			wantMax:   0,
		},
		{
			name:      "5 minutes remaining",
			expiresAt: now.Add(5 * time.Minute),
			wantMin:   4*time.Minute + 59*time.Second, // Account for test execution time
			wantMax:   5 * time.Minute,
		},
		{
			name:      "30 seconds remaining",
			expiresAt: now.Add(30 * time.Second),
			wantMin:   29 * time.Second,
			wantMax:   30 * time.Second,
		},
		{
			name:      "just expired",
			expiresAt: now.Add(-time.Millisecond),
			wantMin:   0,
			wantMax:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lock := &Lock{
				Key:        "test-key",
				HolderID:   "test-holder",
				AcquiredAt: now.Add(-time.Hour),
				ExpiresAt:  tt.expiresAt,
				Token:      "test-token",
			}

			got := lock.RemainingTTL()
			
			if got < tt.wantMin || got > tt.wantMax {
				t.Errorf("RemainingTTL() = %v, want between %v and %v", got, tt.wantMin, tt.wantMax)
			}

			// Expired locks should always return 0
			if tt.expiresAt.Before(time.Now()) && got != 0 {
				t.Errorf("RemainingTTL() for expired lock = %v, want 0", got)
			}
		})
	}
}

func TestDefaultLockConfig(t *testing.T) {
	config := DefaultLockConfig()

	// Test default values
	if config.DefaultTTL != 30*time.Second {
		t.Errorf("DefaultTTL = %v, want %v", config.DefaultTTL, 30*time.Second)
	}

	if config.RetryInterval != 100*time.Millisecond {
		t.Errorf("RetryInterval = %v, want %v", config.RetryInterval, 100*time.Millisecond)
	}

	if config.MaxRetries != 10 {
		t.Errorf("MaxRetries = %d, want %d", config.MaxRetries, 10)
	}

	// InstanceID should be empty (auto-generated when needed)
	if config.InstanceID != "" {
		t.Errorf("InstanceID should be empty, got %q", config.InstanceID)
	}
}

func TestLockConfig_Validation(t *testing.T) {
	// Test that we can create reasonable configurations
	tests := []struct {
		name   string
		config LockConfig
		valid  bool
	}{
		{
			name: "valid config",
			config: LockConfig{
				DefaultTTL:    30 * time.Second,
				RetryInterval: 100 * time.Millisecond,
				MaxRetries:    5,
				InstanceID:    "test-instance",
			},
			valid: true,
		},
		{
			name: "zero values",
			config: LockConfig{
				DefaultTTL:    0,
				RetryInterval: 0,
				MaxRetries:    0,
				InstanceID:    "",
			},
			valid: true, // Zero values are technically valid
		},
		{
			name: "reasonable production config",
			config: LockConfig{
				DefaultTTL:    5 * time.Minute,
				RetryInterval: 250 * time.Millisecond,
				MaxRetries:    20,
				InstanceID:    "prod-instance-123",
			},
			valid: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Just verify the config can be created and accessed
			config := tt.config
			
			if config.DefaultTTL < 0 {
				t.Error("DefaultTTL should not be negative")
			}
			if config.RetryInterval < 0 {
				t.Error("RetryInterval should not be negative")
			}
			if config.MaxRetries < 0 {
				t.Error("MaxRetries should not be negative")
			}
		})
	}
}

func TestLock_Fields(t *testing.T) {
	// Test that Lock struct holds all required fields correctly
	now := time.Now()
	expiresAt := now.Add(30 * time.Second)
	
	lock := &Lock{
		Key:        "test-key-123",
		HolderID:   "holder-456",
		AcquiredAt: now,
		ExpiresAt:  expiresAt,
		Token:      "token-789",
		Metadata:   "test metadata",
	}

	if lock.Key != "test-key-123" {
		t.Errorf("Key = %q, want %q", lock.Key, "test-key-123")
	}

	if lock.HolderID != "holder-456" {
		t.Errorf("HolderID = %q, want %q", lock.HolderID, "holder-456")
	}

	if !lock.AcquiredAt.Equal(now) {
		t.Errorf("AcquiredAt = %v, want %v", lock.AcquiredAt, now)
	}

	if !lock.ExpiresAt.Equal(expiresAt) {
		t.Errorf("ExpiresAt = %v, want %v", lock.ExpiresAt, expiresAt)
	}

	if lock.Token != "token-789" {
		t.Errorf("Token = %q, want %q", lock.Token, "token-789")
	}

	if lock.Metadata != "test metadata" {
		t.Errorf("Metadata = %q, want %q", lock.Metadata, "test metadata")
	}
}

func TestLock_TimeRelatedMethods(t *testing.T) {
	now := time.Now()
	
	// Create a lock that expires in 1 minute
	lock := &Lock{
		Key:        "test-key",
		HolderID:   "test-holder",
		AcquiredAt: now,
		ExpiresAt:  now.Add(time.Minute),
		Token:      "test-token",
	}

	// Should not be expired
	if lock.IsExpired() {
		t.Error("Lock should not be expired yet")
	}

	// Should have close to 1 minute remaining
	remaining := lock.RemainingTTL()
	if remaining < 59*time.Second || remaining > time.Minute {
		t.Errorf("RemainingTTL() = %v, want close to 1 minute", remaining)
	}

	// Test with an already expired lock
	expiredLock := &Lock{
		Key:        "expired-key",
		HolderID:   "test-holder",
		AcquiredAt: now.Add(-2 * time.Minute),
		ExpiresAt:  now.Add(-time.Minute),
		Token:      "test-token",
	}

	if !expiredLock.IsExpired() {
		t.Error("Lock should be expired")
	}

	if expiredLock.RemainingTTL() != 0 {
		t.Errorf("Expired lock RemainingTTL() = %v, want 0", expiredLock.RemainingTTL())
	}
}

func TestLockErrors(t *testing.T) {
	// Test that our error constants are defined and different
	errors := []error{
		ErrLockAcquisitionFailed,
		ErrLockNotFound,
		ErrLockExpired,
		ErrLockNotHeld,
	}

	// Check that all errors are non-nil
	for i, err := range errors {
		if err == nil {
			t.Errorf("Error %d should not be nil", i)
		}
	}

	// Check that all errors have different messages
	messages := make(map[string]bool)
	for _, err := range errors {
		msg := err.Error()
		if messages[msg] {
			t.Errorf("Duplicate error message: %q", msg)
		}
		messages[msg] = true
	}

	// Check that error messages are reasonable
	expectedMessages := map[error]string{
		ErrLockAcquisitionFailed: "failed to acquire lock",
		ErrLockNotFound:          "lock not found",
		ErrLockExpired:           "lock has expired",
		ErrLockNotHeld:           "lock not held by this instance",
	}

	for err, expectedMsg := range expectedMessages {
		if err.Error() != expectedMsg {
			t.Errorf("Error message = %q, want %q", err.Error(), expectedMsg)
		}
	}
}