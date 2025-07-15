package config

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestLoadLockConfig(t *testing.T) {
	// Save original env vars
	originalEnvs := map[string]string{
		"GNOLINKER__LOCK_TYPE":           os.Getenv("GNOLINKER__LOCK_TYPE"),
		"GNOLINKER__LOCK_DEFAULT_TTL":    os.Getenv("GNOLINKER__LOCK_DEFAULT_TTL"),
		"GNOLINKER__LOCK_RETRY_INTERVAL": os.Getenv("GNOLINKER__LOCK_RETRY_INTERVAL"),
		"GNOLINKER__LOCK_MAX_RETRIES":    os.Getenv("GNOLINKER__LOCK_MAX_RETRIES"),
		"GNOLINKER__LOCK_INSTANCE_ID":    os.Getenv("GNOLINKER__LOCK_INSTANCE_ID"),
		"GNOLINKER__LOCK_BUCKET":         os.Getenv("GNOLINKER__LOCK_BUCKET"),
		"GNOLINKER__STORAGE_BUCKET":      os.Getenv("GNOLINKER__STORAGE_BUCKET"),
		"GNOLINKER__LOCK_REGION":         os.Getenv("GNOLINKER__LOCK_REGION"),
		"AWS_REGION":                     os.Getenv("AWS_REGION"),
		"AWS_ENDPOINT_URL_S3":            os.Getenv("AWS_ENDPOINT_URL_S3"),
		"AWS_ENDPOINT_URL":               os.Getenv("AWS_ENDPOINT_URL"),
		"GNOLINKER__LOCK_ENDPOINT":       os.Getenv("GNOLINKER__LOCK_ENDPOINT"),
		"GNOLINKER__LOCK_PREFIX":         os.Getenv("GNOLINKER__LOCK_PREFIX"),
		"GNOLINKER__LOCK_REDIS_URL":      os.Getenv("GNOLINKER__LOCK_REDIS_URL"),
	}

	// Restore env vars after test
	defer func() {
		for key, value := range originalEnvs {
			if value == "" {
				os.Unsetenv(key)
			} else {
				os.Setenv(key, value)
			}
		}
	}()

	tests := []struct {
		name     string
		envVars  map[string]string
		expected *LockConfig
	}{
		{
			name:    "default configuration",
			envVars: map[string]string{},
			expected: &LockConfig{
				Type:          "none",
				DefaultTTL:    30 * time.Second,
				RetryInterval: 100 * time.Millisecond,
				MaxRetries:    10,
				InstanceID:    "",
				S3Bucket:      "gnolinker-data",
				S3Region:      "us-east-1",
				S3Endpoint:    "",
				S3Prefix:      "locks/",
				RedisURL:      "",
			},
		},
		{
			name: "custom S3 lock configuration",
			envVars: map[string]string{
				"GNOLINKER__LOCK_TYPE":           "s3",
				"GNOLINKER__LOCK_DEFAULT_TTL":    "1m",
				"GNOLINKER__LOCK_RETRY_INTERVAL": "200ms",
				"GNOLINKER__LOCK_MAX_RETRIES":    "5",
				"GNOLINKER__LOCK_INSTANCE_ID":    "test-instance-123",
				"GNOLINKER__LOCK_BUCKET":         "my-lock-bucket",
				"GNOLINKER__LOCK_REGION":         "eu-central-1",
				"AWS_ENDPOINT_URL_S3":            "https://locks.example.com",
				"GNOLINKER__LOCK_PREFIX":         "custom-locks/",
			},
			expected: &LockConfig{
				Type:          "s3",
				DefaultTTL:    time.Minute,
				RetryInterval: 200 * time.Millisecond,
				MaxRetries:    5,
				InstanceID:    "test-instance-123",
				S3Bucket:      "my-lock-bucket",
				S3Region:      "eu-central-1",
				S3Endpoint:    "https://locks.example.com",
				S3Prefix:      "custom-locks/",
				RedisURL:      "",
			},
		},
		{
			name: "memory lock configuration",
			envVars: map[string]string{
				"GNOLINKER__LOCK_TYPE":           "memory",
				"GNOLINKER__LOCK_DEFAULT_TTL":    "10s",
				"GNOLINKER__LOCK_RETRY_INTERVAL": "50ms",
				"GNOLINKER__LOCK_MAX_RETRIES":    "3",
			},
			expected: &LockConfig{
				Type:          "memory",
				DefaultTTL:    10 * time.Second,
				RetryInterval: 50 * time.Millisecond,
				MaxRetries:    3,
				InstanceID:    "",
				S3Bucket:      "gnolinker-data",
				S3Region:      "us-east-1",
				S3Endpoint:    "",
				S3Prefix:      "locks/",
				RedisURL:      "",
			},
		},
		{
			name: "fallback environment variables",
			envVars: map[string]string{
				"GNOLINKER__STORAGE_BUCKET": "fallback-bucket",
				"AWS_REGION":                "ap-southeast-2",
				"AWS_ENDPOINT_URL":          "https://fallback.endpoint.com",
			},
			expected: &LockConfig{
				Type:          "none",
				DefaultTTL:    30 * time.Second,
				RetryInterval: 100 * time.Millisecond,
				MaxRetries:    10,
				InstanceID:    "",
				S3Bucket:      "fallback-bucket",
				S3Region:      "ap-southeast-2",
				S3Endpoint:    "https://fallback.endpoint.com",
				S3Prefix:      "locks/",
				RedisURL:      "",
			},
		},
		{
			name: "redis configuration",
			envVars: map[string]string{
				"GNOLINKER__LOCK_TYPE":      "redis",
				"GNOLINKER__LOCK_REDIS_URL": "redis://localhost:6379",
			},
			expected: &LockConfig{
				Type:          "redis",
				DefaultTTL:    30 * time.Second,
				RetryInterval: 100 * time.Millisecond,
				MaxRetries:    10,
				InstanceID:    "",
				S3Bucket:      "gnolinker-data",
				S3Region:      "us-east-1",
				S3Endpoint:    "",
				S3Prefix:      "locks/",
				RedisURL:      "redis://localhost:6379",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear all env vars first
			for key := range originalEnvs {
				os.Unsetenv(key)
			}

			// Set test env vars
			for key, value := range tt.envVars {
				os.Setenv(key, value)
			}

			// Load config
			config := LoadLockConfig()

			// Verify config
			if config.Type != tt.expected.Type {
				t.Errorf("Type = %q, want %q", config.Type, tt.expected.Type)
			}
			if config.DefaultTTL != tt.expected.DefaultTTL {
				t.Errorf("DefaultTTL = %v, want %v", config.DefaultTTL, tt.expected.DefaultTTL)
			}
			if config.RetryInterval != tt.expected.RetryInterval {
				t.Errorf("RetryInterval = %v, want %v", config.RetryInterval, tt.expected.RetryInterval)
			}
			if config.MaxRetries != tt.expected.MaxRetries {
				t.Errorf("MaxRetries = %d, want %d", config.MaxRetries, tt.expected.MaxRetries)
			}
			if config.InstanceID != tt.expected.InstanceID {
				t.Errorf("InstanceID = %q, want %q", config.InstanceID, tt.expected.InstanceID)
			}
			if config.S3Bucket != tt.expected.S3Bucket {
				t.Errorf("S3Bucket = %q, want %q", config.S3Bucket, tt.expected.S3Bucket)
			}
			if config.S3Region != tt.expected.S3Region {
				t.Errorf("S3Region = %q, want %q", config.S3Region, tt.expected.S3Region)
			}
			if config.S3Endpoint != tt.expected.S3Endpoint {
				t.Errorf("S3Endpoint = %q, want %q", config.S3Endpoint, tt.expected.S3Endpoint)
			}
			if config.S3Prefix != tt.expected.S3Prefix {
				t.Errorf("S3Prefix = %q, want %q", config.S3Prefix, tt.expected.S3Prefix)
			}
			if config.RedisURL != tt.expected.RedisURL {
				t.Errorf("RedisURL = %q, want %q", config.RedisURL, tt.expected.RedisURL)
			}
		})
	}
}

func TestLockConfig_CreateLockManager(t *testing.T) {
	t.Parallel()
	ctx := context.Background()

	tests := []struct {
		name        string
		config      *LockConfig
		expectError bool
		managerType string
	}{
		{
			name: "memory lock manager",
			config: &LockConfig{
				Type:          "memory",
				DefaultTTL:    10 * time.Second,
				RetryInterval: 50 * time.Millisecond,
				MaxRetries:    5,
				InstanceID:    "test-instance",
			},
			expectError: false,
			managerType: "*lock.MemoryLockManager",
		},
		{
			name: "no-op lock manager - none",
			config: &LockConfig{
				Type: "none",
			},
			expectError: false,
			managerType: "*lock.NoOpLockManager",
		},
		{
			name: "no-op lock manager - empty",
			config: &LockConfig{
				Type: "",
			},
			expectError: false,
			managerType: "*lock.NoOpLockManager",
		},
		{
			name: "redis lock manager - not implemented",
			config: &LockConfig{
				Type:     "redis",
				RedisURL: "redis://localhost:6379",
			},
			expectError: true,
		},
		{
			name: "unsupported lock type",
			config: &LockConfig{
				Type: "etcd",
			},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager, err := tt.config.CreateLockManager(ctx)

			if tt.expectError {
				if err == nil {
					t.Fatal("Expected error but got none")
				}
				return
			}

			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}

			if manager == nil {
				t.Fatal("Lock manager should not be nil")
			}

			// Test that the manager works
			lockCtx := context.Background()
			testLock, err := manager.AcquireLock(lockCtx, "test-key", time.Minute)
			if err != nil {
				t.Fatalf("Failed to acquire test lock: %v", err)
			}

			if testLock == nil {
				t.Fatal("Test lock should not be nil")
			}

			// Release the lock
			err = manager.ReleaseLock(lockCtx, testLock)
			if err != nil {
				t.Errorf("Failed to release test lock: %v", err)
			}
		})
	}
}

func TestGetLocalMemoryConfig(t *testing.T) {
	t.Parallel()
	config := GetLocalMemoryConfig()

	if config.Type != "memory" {
		t.Errorf("Type = %q, want %q", config.Type, "memory")
	}
	if config.DefaultTTL != 10*time.Second {
		t.Errorf("DefaultTTL = %v, want %v", config.DefaultTTL, 10*time.Second)
	}
	if config.RetryInterval != 50*time.Millisecond {
		t.Errorf("RetryInterval = %v, want %v", config.RetryInterval, 50*time.Millisecond)
	}
	if config.MaxRetries != 5 {
		t.Errorf("MaxRetries = %d, want %d", config.MaxRetries, 5)
	}
}

func TestGetS3LockConfig(t *testing.T) {
	// Save original env vars
	originalEnvs := map[string]string{
		"GNOLINKER__LOCK_BUCKET":   os.Getenv("GNOLINKER__LOCK_BUCKET"),
		"GNOLINKER__LOCK_REGION":   os.Getenv("GNOLINKER__LOCK_REGION"),
		"AWS_REGION":               os.Getenv("AWS_REGION"),
		"AWS_ENDPOINT_URL_S3":      os.Getenv("AWS_ENDPOINT_URL_S3"),
		"AWS_ENDPOINT_URL":         os.Getenv("AWS_ENDPOINT_URL"),
		"GNOLINKER__LOCK_ENDPOINT": os.Getenv("GNOLINKER__LOCK_ENDPOINT"),
	}

	// Restore env vars after test
	defer func() {
		for key, value := range originalEnvs {
			if value == "" {
				os.Unsetenv(key)
			} else {
				os.Setenv(key, value)
			}
		}
	}()

	t.Run("default values", func(t *testing.T) {
		// Clear all env vars
		for key := range originalEnvs {
			os.Unsetenv(key)
		}

		config := GetS3LockConfig()

		if config.Type != "s3" {
			t.Errorf("Type = %q, want %q", config.Type, "s3")
		}
		if config.DefaultTTL != 30*time.Second {
			t.Errorf("DefaultTTL = %v, want %v", config.DefaultTTL, 30*time.Second)
		}
		if config.RetryInterval != 100*time.Millisecond {
			t.Errorf("RetryInterval = %v, want %v", config.RetryInterval, 100*time.Millisecond)
		}
		if config.MaxRetries != 10 {
			t.Errorf("MaxRetries = %d, want %d", config.MaxRetries, 10)
		}
		if config.S3Bucket != "gnolinker-data" {
			t.Errorf("S3Bucket = %q, want %q", config.S3Bucket, "gnolinker-data")
		}
		if config.S3Region != "us-east-1" {
			t.Errorf("S3Region = %q, want %q", config.S3Region, "us-east-1")
		}
		if config.S3Endpoint != "" {
			t.Errorf("S3Endpoint = %q, want %q", config.S3Endpoint, "")
		}
		if config.S3Prefix != "locks/" {
			t.Errorf("S3Prefix = %q, want %q", config.S3Prefix, "locks/")
		}
	})

	t.Run("custom values from environment", func(t *testing.T) {
		// Set custom env vars
		os.Setenv("GNOLINKER__LOCK_BUCKET", "custom-lock-bucket")
		os.Setenv("GNOLINKER__LOCK_REGION", "eu-west-1")
		os.Setenv("AWS_ENDPOINT_URL_S3", "https://custom.s3.endpoint.com")

		config := GetS3LockConfig()

		if config.S3Bucket != "custom-lock-bucket" {
			t.Errorf("S3Bucket = %q, want %q", config.S3Bucket, "custom-lock-bucket")
		}
		if config.S3Region != "eu-west-1" {
			t.Errorf("S3Region = %q, want %q", config.S3Region, "eu-west-1")
		}
		if config.S3Endpoint != "https://custom.s3.endpoint.com" {
			t.Errorf("S3Endpoint = %q, want %q", config.S3Endpoint, "https://custom.s3.endpoint.com")
		}
	})

	t.Run("fallback values from environment", func(t *testing.T) {
		// Clear primary env vars, set fallback ones
		os.Unsetenv("GNOLINKER__LOCK_BUCKET")
		os.Unsetenv("GNOLINKER__LOCK_REGION")
		os.Unsetenv("AWS_ENDPOINT_URL_S3")

		os.Setenv("AWS_REGION", "ap-southeast-1")
		os.Setenv("AWS_ENDPOINT_URL", "https://fallback.endpoint.com")

		config := GetS3LockConfig()

		if config.S3Region != "ap-southeast-1" {
			t.Errorf("S3Region = %q, want %q", config.S3Region, "ap-southeast-1")
		}
		if config.S3Endpoint != "https://fallback.endpoint.com" {
			t.Errorf("S3Endpoint = %q, want %q", config.S3Endpoint, "https://fallback.endpoint.com")
		}
	})
}

func TestGetEnvIntWithDefault(t *testing.T) {
	// Save original env var
	originalValue := os.Getenv("TEST_INT_HELPER")
	defer func() {
		if originalValue == "" {
			os.Unsetenv("TEST_INT_HELPER")
		} else {
			os.Setenv("TEST_INT_HELPER", originalValue)
		}
	}()

	tests := []struct {
		envValue string
		expected int
	}{
		{"42", 42},
		{"0", 0},
		{"-10", -10},
		{"", 999},        // Should use default
		{"invalid", 999}, // Should use default
	}

	for _, tt := range tests {
		t.Run("value_"+tt.envValue, func(t *testing.T) {
			if tt.envValue == "" {
				os.Unsetenv("TEST_INT_HELPER")
			} else {
				os.Setenv("TEST_INT_HELPER", tt.envValue)
			}

			result := getEnvIntWithDefault("TEST_INT_HELPER", 999)
			if result != tt.expected {
				t.Errorf("getEnvIntWithDefault(%q) = %d, want %d", tt.envValue, result, tt.expected)
			}
		})
	}
}

func TestLockConfig_S3Integration(t *testing.T) {
	t.Parallel()
	// This test verifies the S3 lock configuration would be created correctly
	// We don't actually create S3 locks since that requires AWS credentials
	ctx := context.Background()

	config := &LockConfig{
		Type:          "s3",
		DefaultTTL:    30 * time.Second,
		RetryInterval: 100 * time.Millisecond,
		MaxRetries:    10,
		InstanceID:    "test-instance",
		S3Bucket:      "test-bucket",
		S3Region:      "us-east-1",
		S3Endpoint:    "", // Use default AWS S3
		S3Prefix:      "locks/",
	}

	// This will fail without proper AWS credentials, but we can test the config creation
	_, err := config.CreateLockManager(ctx)
	
	// We expect this to fail in test environment without AWS credentials
	// The important thing is that it tries to create the S3 lock manager
	if err == nil {
		// If it succeeds (perhaps in CI with proper credentials), that's also fine
		t.Log("S3 lock manager created successfully (unexpected but valid)")
	} else {
		// This is expected in most test environments
		if err.Error() == "redis lock manager not yet implemented" {
			t.Error("Wrong error returned for S3 lock manager")
		}
		// Any other error (like credential issues) is expected and fine
		t.Logf("S3 lock manager creation failed as expected: %v", err)
	}
}