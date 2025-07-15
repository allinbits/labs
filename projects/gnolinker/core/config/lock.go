package config

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core/lock"
)

// LockConfig holds configuration for distributed locking
type LockConfig struct {
	Type string

	// Common lock settings
	DefaultTTL    time.Duration
	RetryInterval time.Duration
	MaxRetries    int
	InstanceID    string

	// S3-specific settings (reuses storage S3 config by default)
	S3Bucket   string
	S3Region   string
	S3Endpoint string
	S3Prefix   string

	// Redis-specific settings
	RedisURL string
}

// LoadLockConfig loads lock configuration from environment variables
func LoadLockConfig() *LockConfig {
	return &LockConfig{
		Type: getEnvWithDefault("GNOLINKER__LOCK_TYPE", "none"),

		// Common settings
		DefaultTTL:    getEnvDuration("GNOLINKER__LOCK_DEFAULT_TTL", 30*time.Second),
		RetryInterval: getEnvDuration("GNOLINKER__LOCK_RETRY_INTERVAL", 100*time.Millisecond),
		MaxRetries:    getEnvInt("GNOLINKER__LOCK_MAX_RETRIES", 10),
		InstanceID:    os.Getenv("GNOLINKER__LOCK_INSTANCE_ID"), // Auto-generated if empty

		// S3 settings (fallback to storage config)
		S3Bucket:   getEnvWithFallbackAndDefault("GNOLINKER__LOCK_BUCKET", "GNOLINKER__STORAGE_BUCKET", "gnolinker-data"),
		S3Region:   getEnvWithFallbackAndDefault("GNOLINKER__LOCK_REGION", "AWS_REGION", "us-east-1"),
		S3Endpoint: getEnvWithMultipleFallbacks("AWS_ENDPOINT_URL_S3", "AWS_ENDPOINT_URL", "GNOLINKER__LOCK_ENDPOINT"),
		S3Prefix:   getEnvWithDefault("GNOLINKER__LOCK_PREFIX", "locks/"),

		// Redis settings
		RedisURL: os.Getenv("GNOLINKER__LOCK_REDIS_URL"),
	}
}

// CreateLockManager creates a lock manager based on the configuration
func (c *LockConfig) CreateLockManager(ctx context.Context) (lock.LockManager, error) {
	switch strings.ToLower(c.Type) {
	case "s3":
		s3Config := lock.S3LockConfig{
			Bucket:   c.S3Bucket,
			Region:   c.S3Region,
			Endpoint: c.S3Endpoint,
			Prefix:   c.S3Prefix,
			LockConfig: lock.LockConfig{
				DefaultTTL:    c.DefaultTTL,
				RetryInterval: c.RetryInterval,
				MaxRetries:    c.MaxRetries,
				InstanceID:    c.InstanceID,
			},
		}
		return lock.NewS3LockManager(ctx, s3Config)

	case "memory":
		memConfig := lock.LockConfig{
			DefaultTTL:    c.DefaultTTL,
			RetryInterval: c.RetryInterval,
			MaxRetries:    c.MaxRetries,
			InstanceID:    c.InstanceID,
		}
		return lock.NewMemoryLockManager(memConfig), nil

	case "redis":
		return nil, fmt.Errorf("redis lock manager not yet implemented")

	case "none", "":
		return lock.NewNoOpLockManager(), nil

	default:
		return nil, fmt.Errorf("unsupported lock type: %s", c.Type)
	}
}

// GetLocalMemoryConfig returns a pre-configured LockConfig for local memory locking
func GetLocalMemoryConfig() *LockConfig {
	return &LockConfig{
		Type:          "memory",
		DefaultTTL:    10 * time.Second,
		RetryInterval: 50 * time.Millisecond,
		MaxRetries:    5,
	}
}

// GetS3LockConfig returns a pre-configured LockConfig for S3 distributed locking
func GetS3LockConfig() *LockConfig {
	return &LockConfig{
		Type:          "s3",
		DefaultTTL:    30 * time.Second,
		RetryInterval: 100 * time.Millisecond,
		MaxRetries:    10,
		S3Bucket:      getEnvWithDefault("GNOLINKER__LOCK_BUCKET", "gnolinker-data"),
		S3Region:      getEnvWithFallbackAndDefault("GNOLINKER__LOCK_REGION", "AWS_REGION", "us-east-1"),
		S3Endpoint:    getEnvWithMultipleFallbacks("AWS_ENDPOINT_URL_S3", "AWS_ENDPOINT_URL", "GNOLINKER__LOCK_ENDPOINT"),
		S3Prefix:      "locks/",
	}
}

// Helper function for parsing integers from environment variables
func getEnvIntWithDefault(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}