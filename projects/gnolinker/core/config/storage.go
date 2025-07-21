package config

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core/storage"
)

// StorageConfig holds configuration for the storage backend
type StorageConfig struct {
	Type string

	// S3 Configuration
	S3Bucket   string
	S3Region   string
	S3Endpoint string // For Minio/Tigris - leave empty for AWS S3
	S3Prefix   string
	// Note: S3AccessKeyID and S3SecretAccessKey removed - AWS SDK handles credentials

	// Cache Configuration
	CacheSize int
	CacheTTL  time.Duration

	// Default Settings
	DefaultVerifiedRoleName string
	AutoCreateRoles         bool
}

// LoadStorageConfig loads storage configuration from environment variables
func LoadStorageConfig() *StorageConfig {
	return &StorageConfig{
		Type: getEnvWithDefault("GNOLINKER__STORAGE_TYPE", "memory"),

		// S3 Configuration
		S3Bucket:   getEnvWithFallbackAndDefault("GNOLINKER__STORAGE_BUCKET", "GNOLINKER__S3_BUCKET", "gnolinker-data"),
		S3Region:   getEnvWithFallbackAndDefault("GNOLINKER__S3_REGION", "AWS_REGION", "us-east-1"),                  // Prefer AWS standard, allow override
		S3Endpoint: getEnvWithMultipleFallbacks("AWS_ENDPOINT_URL_S3", "AWS_ENDPOINT_URL", "GNOLINKER__S3_ENDPOINT"), // AWS SDK standard, fallback to custom
		S3Prefix:   getEnvWithDefault("GNOLINKER__STORAGE_PREFIX", "configs"),
		// Note: AWS SDK automatically uses AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, and AWS_ENDPOINT_URL_S3/AWS_ENDPOINT_URL

		// Cache Configuration
		CacheSize: getEnvInt("GNOLINKER__CACHE_SIZE", 100),
		CacheTTL:  getEnvDuration("GNOLINKER__CACHE_TTL", time.Hour),

		// Default Settings
		DefaultVerifiedRoleName: getEnvWithDefault("GNOLINKER__DEFAULT_VERIFIED_ROLE_NAME", "Gno-Verified"),
		AutoCreateRoles:         getEnvBool("GNOLINKER__AUTO_CREATE_ROLES", true),
	}
}

// CreateConfigStore creates a ConfigStore based on the configuration
func (c *StorageConfig) CreateConfigStore(ctx context.Context) (storage.ConfigStore, error) {
	var baseStore storage.ConfigStore
	var err error

	switch strings.ToLower(c.Type) {
	case "s3":
		s3Config := storage.S3Config{
			Bucket:   c.S3Bucket,
			Region:   c.S3Region,
			Endpoint: c.S3Endpoint,
			Prefix:   c.S3Prefix,
		}
		baseStore, err = storage.NewS3ConfigStore(ctx, s3Config)
		if err != nil {
			return nil, fmt.Errorf("failed to create S3 config store: %w", err)
		}

	case "memory":
		baseStore = storage.NewMemoryConfigStore()

	default:
		return nil, fmt.Errorf("unsupported storage type: %s", c.Type)
	}

	// Wrap with cache if cache size > 0
	if c.CacheSize > 0 {
		cacheConfig := storage.CacheConfig{
			Size: c.CacheSize,
			TTL:  c.CacheTTL,
		}
		cachedStore, err := storage.NewCachedConfigStore(baseStore, cacheConfig)
		if err != nil {
			return nil, fmt.Errorf("failed to create cached config store: %w", err)
		}
		return cachedStore, nil
	}

	return baseStore, nil
}

// GetMinioLocalConfig returns a pre-configured StorageConfig for local Minio development
func GetMinioLocalConfig() *StorageConfig {
	return &StorageConfig{
		Type:                    "s3",
		S3Bucket:                "gnolinker-dev",
		S3Region:                "us-east-1",
		S3Endpoint:              "http://localhost:9000",
		S3Prefix:                "configs",
		CacheSize:               50,
		CacheTTL:                30 * time.Minute,
		DefaultVerifiedRoleName: "Gno-Verified",
		AutoCreateRoles:         true,
		// Note: AWS_ACCESS_KEY_ID=minioadmin and AWS_SECRET_ACCESS_KEY=minioadmin should be set as env vars
	}
}

// GetTigrisProductionConfig returns a pre-configured StorageConfig for Tigris on Fly.io
func GetTigrisProductionConfig() *StorageConfig {
	return &StorageConfig{
		Type:                    "s3",
		S3Bucket:                getEnvWithDefault("GNOLINKER__STORAGE_BUCKET", "gnolinker-prod"),
		S3Region:                "auto", // Tigris uses "auto" region
		S3Endpoint:              "https://fly.storage.tigris.dev",
		S3Prefix:                "configs",
		CacheSize:               200,
		CacheTTL:                time.Hour,
		DefaultVerifiedRoleName: "Gno-Verified",
		AutoCreateRoles:         true,
		// Note: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars used automatically by AWS SDK
	}
}

// Helper functions for environment variable parsing

func getEnvWithDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvWithFallbackAndDefault(primaryKey, fallbackKey, defaultValue string) string {
	if value := os.Getenv(primaryKey); value != "" {
		return value
	}
	if value := os.Getenv(fallbackKey); value != "" {
		return value
	}
	return defaultValue
}

func getEnvWithMultipleFallbacks(primaryKey, secondaryKey, tertiaryKey string) string {
	if value := os.Getenv(primaryKey); value != "" {
		return value
	}
	if value := os.Getenv(secondaryKey); value != "" {
		return value
	}
	if value := os.Getenv(tertiaryKey); value != "" {
		return value
	}
	return ""
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.ParseBool(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}

func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if parsed, err := time.ParseDuration(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}
