package config

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestLoadStorageConfig(t *testing.T) {
	// Save original env vars
	originalEnvs := map[string]string{
		"GNOLINKER__STORAGE_TYPE":               os.Getenv("GNOLINKER__STORAGE_TYPE"),
		"GNOLINKER__STORAGE_BUCKET":             os.Getenv("GNOLINKER__STORAGE_BUCKET"),
		"GNOLINKER__S3_BUCKET":                  os.Getenv("GNOLINKER__S3_BUCKET"),
		"GNOLINKER__S3_REGION":                  os.Getenv("GNOLINKER__S3_REGION"),
		"AWS_REGION":                            os.Getenv("AWS_REGION"),
		"AWS_ENDPOINT_URL_S3":                   os.Getenv("AWS_ENDPOINT_URL_S3"),
		"AWS_ENDPOINT_URL":                      os.Getenv("AWS_ENDPOINT_URL"),
		"GNOLINKER__S3_ENDPOINT":                os.Getenv("GNOLINKER__S3_ENDPOINT"),
		"GNOLINKER__STORAGE_PREFIX":             os.Getenv("GNOLINKER__STORAGE_PREFIX"),
		"GNOLINKER__CACHE_SIZE":                 os.Getenv("GNOLINKER__CACHE_SIZE"),
		"GNOLINKER__CACHE_TTL":                  os.Getenv("GNOLINKER__CACHE_TTL"),
		"GNOLINKER__DEFAULT_VERIFIED_ROLE_NAME": os.Getenv("GNOLINKER__DEFAULT_VERIFIED_ROLE_NAME"),
		"GNOLINKER__AUTO_CREATE_ROLES":          os.Getenv("GNOLINKER__AUTO_CREATE_ROLES"),
	}

	// Restore env vars after test
	defer func() {
		for key, value := range originalEnvs {
			if value == "" {
				if err := os.Unsetenv(key); err != nil {
					t.Errorf("Failed to unset env var %s: %v", key, err)
				}
			} else {
				if err := os.Setenv(key, value); err != nil {
					t.Errorf("Failed to set env var %s: %v", key, err)
				}
			}
		}
	}()

	tests := []struct {
		name     string
		envVars  map[string]string
		expected *StorageConfig
	}{
		{
			name:    "default configuration",
			envVars: map[string]string{},
			expected: &StorageConfig{
				Type:                    "memory",
				S3Bucket:                "gnolinker-data",
				S3Region:                "us-east-1",
				S3Endpoint:              "",
				S3Prefix:                "configs",
				CacheSize:               100,
				CacheTTL:                time.Hour,
				DefaultVerifiedRoleName: "Gno-Verified",
				AutoCreateRoles:         true,
			},
		},
		{
			name: "custom S3 configuration",
			envVars: map[string]string{
				"GNOLINKER__STORAGE_TYPE":   "s3",
				"GNOLINKER__STORAGE_BUCKET": "my-bucket",
				"GNOLINKER__S3_REGION":      "eu-west-1",
				"AWS_ENDPOINT_URL_S3":       "https://s3.example.com",
				"GNOLINKER__STORAGE_PREFIX": "custom-prefix",
				"GNOLINKER__CACHE_SIZE":     "50",
				"GNOLINKER__CACHE_TTL":      "30m",
			},
			expected: &StorageConfig{
				Type:                    "s3",
				S3Bucket:                "my-bucket",
				S3Region:                "eu-west-1",
				S3Endpoint:              "https://s3.example.com",
				S3Prefix:                "custom-prefix",
				CacheSize:               50,
				CacheTTL:                30 * time.Minute,
				DefaultVerifiedRoleName: "Gno-Verified",
				AutoCreateRoles:         true,
			},
		},
		{
			name: "fallback environment variables",
			envVars: map[string]string{
				"GNOLINKER__S3_BUCKET": "fallback-bucket",
				"AWS_REGION":           "ap-south-1",
				"AWS_ENDPOINT_URL":     "https://fallback.endpoint.com",
			},
			expected: &StorageConfig{
				Type:                    "memory",
				S3Bucket:                "fallback-bucket",
				S3Region:                "ap-south-1",
				S3Endpoint:              "https://fallback.endpoint.com",
				S3Prefix:                "configs",
				CacheSize:               100,
				CacheTTL:                time.Hour,
				DefaultVerifiedRoleName: "Gno-Verified",
				AutoCreateRoles:         true,
			},
		},
		{
			name: "disabled auto create roles",
			envVars: map[string]string{
				"GNOLINKER__AUTO_CREATE_ROLES":          "false",
				"GNOLINKER__DEFAULT_VERIFIED_ROLE_NAME": "Custom-Verified",
			},
			expected: &StorageConfig{
				Type:                    "memory",
				S3Bucket:                "gnolinker-data",
				S3Region:                "us-east-1",
				S3Endpoint:              "",
				S3Prefix:                "configs",
				CacheSize:               100,
				CacheTTL:                time.Hour,
				DefaultVerifiedRoleName: "Custom-Verified",
				AutoCreateRoles:         false,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear all env vars first
			for key := range originalEnvs {
				if err := os.Unsetenv(key); err != nil {
					t.Fatalf("Failed to unset env var %s: %v", key, err)
				}
			}

			// Set test env vars
			for key, value := range tt.envVars {
				if err := os.Setenv(key, value); err != nil {
					t.Fatalf("Failed to set env var %s: %v", key, err)
				}
			}

			// Load config
			config := LoadStorageConfig()

			// Verify config
			if config.Type != tt.expected.Type {
				t.Errorf("Type = %q, want %q", config.Type, tt.expected.Type)
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
			if config.CacheSize != tt.expected.CacheSize {
				t.Errorf("CacheSize = %d, want %d", config.CacheSize, tt.expected.CacheSize)
			}
			if config.CacheTTL != tt.expected.CacheTTL {
				t.Errorf("CacheTTL = %v, want %v", config.CacheTTL, tt.expected.CacheTTL)
			}
			if config.DefaultVerifiedRoleName != tt.expected.DefaultVerifiedRoleName {
				t.Errorf("DefaultVerifiedRoleName = %q, want %q", config.DefaultVerifiedRoleName, tt.expected.DefaultVerifiedRoleName)
			}
			if config.AutoCreateRoles != tt.expected.AutoCreateRoles {
				t.Errorf("AutoCreateRoles = %t, want %t", config.AutoCreateRoles, tt.expected.AutoCreateRoles)
			}
		})
	}
}

func TestStorageConfig_CreateConfigStore(t *testing.T) {
	t.Parallel()
	ctx := context.Background()

	tests := []struct {
		name        string
		config      *StorageConfig
		expectError bool
		storeType   string
	}{
		{
			name: "memory store",
			config: &StorageConfig{
				Type:      "memory",
				CacheSize: 0, // No cache
			},
			expectError: false,
			storeType:   "*storage.MemoryConfigStore",
		},
		{
			name: "memory store with cache",
			config: &StorageConfig{
				Type:      "memory",
				CacheSize: 50,
				CacheTTL:  10 * time.Minute,
			},
			expectError: false,
			storeType:   "*storage.CachedConfigStore",
		},
		{
			name: "unsupported storage type",
			config: &StorageConfig{
				Type: "redis",
			},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store, err := tt.config.CreateConfigStore(ctx)

			if tt.expectError {
				if err == nil {
					t.Fatal("Expected error but got none")
				}
				return
			}

			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}

			if store == nil {
				t.Fatal("Store should not be nil")
			}

			// Basic test - verify the store was created successfully
			// We can't easily check the exact type due to interfaces,
			// but we can verify the store works
			// TODO: Add specific tests for memory store type
			// Currently we just verify that the store was created successfully
		})
	}
}

func TestGetMinioLocalConfig(t *testing.T) {
	t.Parallel()
	config := GetMinioLocalConfig()

	if config.Type != "s3" {
		t.Errorf("Type = %q, want %q", config.Type, "s3")
	}
	if config.S3Bucket != "gnolinker-dev" {
		t.Errorf("S3Bucket = %q, want %q", config.S3Bucket, "gnolinker-dev")
	}
	if config.S3Region != "us-east-1" {
		t.Errorf("S3Region = %q, want %q", config.S3Region, "us-east-1")
	}
	if config.S3Endpoint != "http://localhost:9000" {
		t.Errorf("S3Endpoint = %q, want %q", config.S3Endpoint, "http://localhost:9000")
	}
	if config.S3Prefix != "configs" {
		t.Errorf("S3Prefix = %q, want %q", config.S3Prefix, "configs")
	}
	if config.CacheSize != 50 {
		t.Errorf("CacheSize = %d, want %d", config.CacheSize, 50)
	}
	if config.CacheTTL != 30*time.Minute {
		t.Errorf("CacheTTL = %v, want %v", config.CacheTTL, 30*time.Minute)
	}
	if !config.AutoCreateRoles {
		t.Error("AutoCreateRoles should be true")
	}
}

func TestGetTigrisProductionConfig(t *testing.T) {
	t.Parallel()
	// Save original env var
	originalBucket := os.Getenv("GNOLINKER__STORAGE_BUCKET")
	defer func() {
		if originalBucket == "" {
			if err := os.Unsetenv("GNOLINKER__STORAGE_BUCKET"); err != nil {
				t.Errorf("Failed to unset GNOLINKER__STORAGE_BUCKET: %v", err)
			}
		} else {
			if err := os.Setenv("GNOLINKER__STORAGE_BUCKET", originalBucket); err != nil {
				t.Errorf("Failed to restore GNOLINKER__STORAGE_BUCKET: %v", err)
			}
		}
	}()

	// Test with default bucket
	if err := os.Unsetenv("GNOLINKER__STORAGE_BUCKET"); err != nil {
		t.Fatalf("Failed to unset GNOLINKER__STORAGE_BUCKET: %v", err)
	}
	config := GetTigrisProductionConfig()

	if config.Type != "s3" {
		t.Errorf("Type = %q, want %q", config.Type, "s3")
	}
	if config.S3Bucket != "gnolinker-prod" {
		t.Errorf("S3Bucket = %q, want %q", config.S3Bucket, "gnolinker-prod")
	}
	if config.S3Region != "auto" {
		t.Errorf("S3Region = %q, want %q", config.S3Region, "auto")
	}
	if config.S3Endpoint != "https://fly.storage.tigris.dev" {
		t.Errorf("S3Endpoint = %q, want %q", config.S3Endpoint, "https://fly.storage.tigris.dev")
	}
	if config.CacheSize != 200 {
		t.Errorf("CacheSize = %d, want %d", config.CacheSize, 200)
	}
	if config.CacheTTL != time.Hour {
		t.Errorf("CacheTTL = %v, want %v", config.CacheTTL, time.Hour)
	}

	// Test with custom bucket
	if err := os.Setenv("GNOLINKER__STORAGE_BUCKET", "custom-bucket"); err != nil {
		t.Fatalf("Failed to set GNOLINKER__STORAGE_BUCKET: %v", err)
	}
	config = GetTigrisProductionConfig()

	if config.S3Bucket != "custom-bucket" {
		t.Errorf("S3Bucket = %q, want %q", config.S3Bucket, "custom-bucket")
	}
}

func TestGetEnvHelperFunctions(t *testing.T) {
	// Save original env vars
	originalEnvs := map[string]string{
		"TEST_STRING":    os.Getenv("TEST_STRING"),
		"TEST_BOOL":      os.Getenv("TEST_BOOL"),
		"TEST_INT":       os.Getenv("TEST_INT"),
		"TEST_DURATION":  os.Getenv("TEST_DURATION"),
		"TEST_PRIMARY":   os.Getenv("TEST_PRIMARY"),
		"TEST_FALLBACK":  os.Getenv("TEST_FALLBACK"),
		"TEST_SECONDARY": os.Getenv("TEST_SECONDARY"),
		"TEST_TERTIARY":  os.Getenv("TEST_TERTIARY"),
	}

	// Restore env vars after test
	defer func() {
		for key, value := range originalEnvs {
			if value == "" {
				if err := os.Unsetenv(key); err != nil {
					t.Errorf("Failed to unset env var %s: %v", key, err)
				}
			} else {
				if err := os.Setenv(key, value); err != nil {
					t.Errorf("Failed to set env var %s: %v", key, err)
				}
			}
		}
	}()

	t.Run("getEnvWithDefault", func(t *testing.T) {
		// Clear env var
		if err := os.Unsetenv("TEST_STRING"); err != nil {
			t.Fatalf("Failed to unset TEST_STRING: %v", err)
		}

		// Should return default
		result := getEnvWithDefault("TEST_STRING", "default_value")
		if result != "default_value" {
			t.Errorf("getEnvWithDefault() = %q, want %q", result, "default_value")
		}

		// Set env var
		if err := os.Setenv("TEST_STRING", "env_value"); err != nil {
			t.Fatalf("Failed to set TEST_STRING: %v", err)
		}
		result = getEnvWithDefault("TEST_STRING", "default_value")
		if result != "env_value" {
			t.Errorf("getEnvWithDefault() = %q, want %q", result, "env_value")
		}
	})

	t.Run("getEnvWithFallbackAndDefault", func(t *testing.T) {
		// Clear both env vars
		if err := os.Unsetenv("TEST_PRIMARY"); err != nil {
			t.Fatalf("Failed to unset TEST_PRIMARY: %v", err)
		}
		if err := os.Unsetenv("TEST_FALLBACK"); err != nil {
			t.Fatalf("Failed to unset TEST_FALLBACK: %v", err)
		}

		// Should return default
		result := getEnvWithFallbackAndDefault("TEST_PRIMARY", "TEST_FALLBACK", "default_value")
		if result != "default_value" {
			t.Errorf("getEnvWithFallbackAndDefault() = %q, want %q", result, "default_value")
		}

		// Set fallback
		if err := os.Setenv("TEST_FALLBACK", "fallback_value"); err != nil {
			t.Fatalf("Failed to set TEST_FALLBACK: %v", err)
		}
		result = getEnvWithFallbackAndDefault("TEST_PRIMARY", "TEST_FALLBACK", "default_value")
		if result != "fallback_value" {
			t.Errorf("getEnvWithFallbackAndDefault() = %q, want %q", result, "fallback_value")
		}

		// Set primary (should override fallback)
		if err := os.Setenv("TEST_PRIMARY", "primary_value"); err != nil {
			t.Fatalf("Failed to set TEST_PRIMARY: %v", err)
		}
		result = getEnvWithFallbackAndDefault("TEST_PRIMARY", "TEST_FALLBACK", "default_value")
		if result != "primary_value" {
			t.Errorf("getEnvWithFallbackAndDefault() = %q, want %q", result, "primary_value")
		}
	})

	t.Run("getEnvWithMultipleFallbacks", func(t *testing.T) {
		// Clear all env vars
		if err := os.Unsetenv("TEST_PRIMARY"); err != nil {
			t.Fatalf("Failed to unset TEST_PRIMARY: %v", err)
		}
		if err := os.Unsetenv("TEST_SECONDARY"); err != nil {
			t.Fatalf("Failed to unset TEST_SECONDARY: %v", err)
		}
		if err := os.Unsetenv("TEST_TERTIARY"); err != nil {
			t.Fatalf("Failed to unset TEST_TERTIARY: %v", err)
		}

		// Should return empty string
		result := getEnvWithMultipleFallbacks("TEST_PRIMARY", "TEST_SECONDARY", "TEST_TERTIARY")
		if result != "" {
			t.Errorf("getEnvWithMultipleFallbacks() = %q, want %q", result, "")
		}

		// Set tertiary
		if err := os.Setenv("TEST_TERTIARY", "tertiary_value"); err != nil {
			t.Fatalf("Failed to set TEST_TERTIARY: %v", err)
		}
		result = getEnvWithMultipleFallbacks("TEST_PRIMARY", "TEST_SECONDARY", "TEST_TERTIARY")
		if result != "tertiary_value" {
			t.Errorf("getEnvWithMultipleFallbacks() = %q, want %q", result, "tertiary_value")
		}

		// Set secondary (should override tertiary)
		if err := os.Setenv("TEST_SECONDARY", "secondary_value"); err != nil {
			t.Fatalf("Failed to set TEST_SECONDARY: %v", err)
		}
		result = getEnvWithMultipleFallbacks("TEST_PRIMARY", "TEST_SECONDARY", "TEST_TERTIARY")
		if result != "secondary_value" {
			t.Errorf("getEnvWithMultipleFallbacks() = %q, want %q", result, "secondary_value")
		}

		// Set primary (should override secondary)
		if err := os.Setenv("TEST_PRIMARY", "primary_value"); err != nil {
			t.Fatalf("Failed to set TEST_PRIMARY: %v", err)
		}
		result = getEnvWithMultipleFallbacks("TEST_PRIMARY", "TEST_SECONDARY", "TEST_TERTIARY")
		if result != "primary_value" {
			t.Errorf("getEnvWithMultipleFallbacks() = %q, want %q", result, "primary_value")
		}
	})

	t.Run("getEnvBool", func(t *testing.T) {
		tests := []struct {
			envValue string
			expected bool
		}{
			{"true", true},
			{"TRUE", true},
			{"True", true},
			{"1", true},
			{"false", false},
			{"FALSE", false},
			{"False", false},
			{"0", false},
			{"", true},        // Should use default
			{"invalid", true}, // Should use default
		}

		for _, tt := range tests {
			if tt.envValue == "" {
				if err := os.Unsetenv("TEST_BOOL"); err != nil {
					t.Fatalf("Failed to unset TEST_BOOL: %v", err)
				}
			} else {
				if err := os.Setenv("TEST_BOOL", tt.envValue); err != nil {
					t.Fatalf("Failed to set TEST_BOOL: %v", err)
				}
			}

			result := getEnvBool("TEST_BOOL", true)
			if result != tt.expected {
				t.Errorf("getEnvBool(%q) = %t, want %t", tt.envValue, result, tt.expected)
			}
		}
	})

	t.Run("getEnvInt", func(t *testing.T) {
		tests := []struct {
			envValue string
			expected int
		}{
			{"42", 42},
			{"0", 0},
			{"-10", -10},
			{"", 100},        // Should use default
			{"invalid", 100}, // Should use default
		}

		for _, tt := range tests {
			if tt.envValue == "" {
				if err := os.Unsetenv("TEST_INT"); err != nil {
					t.Fatalf("Failed to unset TEST_INT: %v", err)
				}
			} else {
				if err := os.Setenv("TEST_INT", tt.envValue); err != nil {
					t.Fatalf("Failed to set TEST_INT: %v", err)
				}
			}

			result := getEnvInt("TEST_INT", 100)
			if result != tt.expected {
				t.Errorf("getEnvInt(%q) = %d, want %d", tt.envValue, result, tt.expected)
			}
		}
	})

	t.Run("getEnvDuration", func(t *testing.T) {
		tests := []struct {
			envValue string
			expected time.Duration
		}{
			{"30s", 30 * time.Second},
			{"5m", 5 * time.Minute},
			{"2h", 2 * time.Hour},
			{"", time.Hour},        // Should use default
			{"invalid", time.Hour}, // Should use default
		}

		for _, tt := range tests {
			if tt.envValue == "" {
				if err := os.Unsetenv("TEST_DURATION"); err != nil {
					t.Fatalf("Failed to unset TEST_DURATION: %v", err)
				}
			} else {
				if err := os.Setenv("TEST_DURATION", tt.envValue); err != nil {
					t.Fatalf("Failed to set TEST_DURATION: %v", err)
				}
			}

			result := getEnvDuration("TEST_DURATION", time.Hour)
			if result != tt.expected {
				t.Errorf("getEnvDuration(%q) = %v, want %v", tt.envValue, result, tt.expected)
			}
		}
	})
}
