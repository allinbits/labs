package config

import (
	"context"
	"fmt"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
)

// InitializeStorage initializes the storage backend and performs health checks
func InitializeStorage(ctx context.Context, logger core.Logger) (storage.ConfigStore, error) {
	logger.Info("Initializing storage backend...")
	
	// Load configuration
	config := LoadStorageConfig()
	logger.Info("Storage configuration loaded", 
		"type", config.Type,
		"bucket", config.S3Bucket,
		"endpoint", config.S3Endpoint,
		"cache_size", config.CacheSize,
		"cache_ttl", config.CacheTTL,
	)

	// Create storage backend
	store, err := config.CreateConfigStore(ctx)
	if err != nil {
		logger.Error("Failed to create storage backend", "error", err)
		return nil, fmt.Errorf("storage initialization failed: %w", err)
	}

	logger.Info("Storage backend created successfully", "type", config.Type)

	// Perform health checks
	if err := performStorageHealthCheck(ctx, store, config, logger); err != nil {
		logger.Error("Storage health check failed", "error", err)
		return nil, fmt.Errorf("storage health check failed: %w", err)
	}

	logger.Info("Storage backend initialized and healthy", 
		"type", config.Type,
		"ready", true,
	)

	return store, nil
}

// InitializeLockManager initializes the distributed lock manager
func InitializeLockManager(ctx context.Context, logger core.Logger) (lock.LockManager, error) {
	logger.Info("Initializing lock manager...")
	
	// Load lock configuration
	config := LoadLockConfig()
	logger.Info("Lock configuration loaded", 
		"type", config.Type,
		"default_ttl", config.DefaultTTL,
		"max_retries", config.MaxRetries,
	)

	// Create lock manager
	lockManager, err := config.CreateLockManager(ctx)
	if err != nil {
		logger.Error("Failed to create lock manager", "error", err)
		return nil, fmt.Errorf("lock manager initialization failed: %w", err)
	}

	logger.Info("Lock manager created successfully", "type", config.Type)
	return lockManager, nil
}

// InitializeConfigManager initializes both storage and lock manager, then creates a ConfigManager
func InitializeConfigManager(ctx context.Context, logger core.Logger) (*ConfigManager, error) {
	// Initialize storage
	store, err := InitializeStorage(ctx, logger)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize storage: %w", err)
	}

	// Initialize lock manager (non-fatal if it fails)
	lockManager, err := InitializeLockManager(ctx, logger)
	if err != nil {
		logger.Warn("Failed to initialize lock manager, continuing without distributed locks", "error", err)
		lockManager = lock.NewNoOpLockManager()
	}

	// Load storage configuration for ConfigManager
	storageConfig := LoadStorageConfig()

	// Create ConfigManager
	configManager := NewConfigManager(store, storageConfig, lockManager, logger)
	
	logger.Info("ConfigManager initialized successfully", 
		"storage_type", storageConfig.Type,
		"lock_type", "enabled",
	)

	return configManager, nil
}

// performStorageHealthCheck runs health checks on the storage backend
func performStorageHealthCheck(ctx context.Context, store storage.ConfigStore, config *StorageConfig, logger core.Logger) error {
	logger.Info("Running storage health checks...")

	// For S3-based storage, run comprehensive health checks
	if config.Type == "s3" {
		// Try to unwrap to get the underlying S3 store
		var s3Store *storage.S3ConfigStore
		
		// Check if it's a cached store wrapping an S3 store
		if cachedStore, ok := store.(*storage.CachedConfigStore); ok {
			// We need to access the backend, but it's private
			// For now, we'll create a temporary S3 store for health check
			s3Config := storage.S3Config{
				Bucket:   config.S3Bucket,
				Region:   config.S3Region,
				Endpoint: config.S3Endpoint,
				Prefix:   config.S3Prefix,
			}
			
			tempS3Store, err := storage.NewS3ConfigStore(ctx, s3Config)
			if err != nil {
				return fmt.Errorf("failed to create temporary S3 store for health check: %w", err)
			}
			s3Store = tempS3Store
			
			// Log cache stats
			cacheSize := cachedStore.CacheStats()
			logger.Info("Cache initialized", "current_size", cacheSize, "max_size", config.CacheSize)
			
		} else if directS3Store, ok := store.(*storage.S3ConfigStore); ok {
			s3Store = directS3Store
		}

		if s3Store != nil {
			logger.Info("Running S3 health checks...", "bucket", config.S3Bucket, "endpoint", config.S3Endpoint)
			
			// Ensure bucket exists
			if err := s3Store.EnsureBucket(ctx); err != nil {
				return fmt.Errorf("bucket verification failed: %w", err)
			}
			logger.Info("Bucket verified", "bucket", config.S3Bucket)

			// Run full health check
			if err := s3Store.HealthCheck(ctx); err != nil {
				return fmt.Errorf("S3 health check failed: %w", err)
			}
			logger.Info("S3 health check passed", "bucket", config.S3Bucket)
		}
	}

	// Test basic store operations
	if err := testBasicStoreOperations(ctx, store, logger); err != nil {
		return fmt.Errorf("basic store operations test failed: %w", err)
	}

	logger.Info("All storage health checks passed")
	return nil
}

// testBasicStoreOperations tests basic CRUD operations on the store
func testBasicStoreOperations(ctx context.Context, store storage.ConfigStore, logger core.Logger) error {
	logger.Info("Testing basic store operations...")
	
	testGuildID := "__startup_test__"
	
	// Create test config
	testConfig := storage.NewGuildConfig(testGuildID)
	testConfig.SetString("test_key", "test_value")
	
	// Test Set
	if err := store.Set(testGuildID, testConfig); err != nil {
		return fmt.Errorf("store Set operation failed: %w", err)
	}
	logger.Info("Store Set operation successful")

	// Test Get
	retrievedConfig, err := store.Get(testGuildID)
	if err != nil {
		return fmt.Errorf("store Get operation failed: %w", err)
	}
	
	if retrievedConfig.GetString("test_key", "") != "test_value" {
		return fmt.Errorf("store Get returned incorrect data")
	}
	logger.Info("Store Get operation successful")

	// Test Delete
	if err := store.Delete(testGuildID); err != nil {
		return fmt.Errorf("store Delete operation failed: %w", err)
	}
	logger.Info("Store Delete operation successful")

	// Verify delete worked
	_, err = store.Get(testGuildID)
	if err == nil {
		return fmt.Errorf("store Delete did not remove the config")
	}
	logger.Info("Store Delete verification successful")

	return nil
}

// LogStorageInfo logs detailed information about the storage configuration
func LogStorageInfo(config *StorageConfig, logger core.Logger) {
	logger.Info("Storage Configuration Details",
		"type", config.Type,
		"cache_enabled", config.CacheSize > 0,
		"cache_size", config.CacheSize,
		"cache_ttl", config.CacheTTL,
		"auto_create_roles", config.AutoCreateRoles,
		"default_verified_role", config.DefaultVerifiedRoleName,
	)

	if config.Type == "s3" {
		logger.Info("S3 Storage Configuration",
			"bucket", config.S3Bucket,
			"region", config.S3Region,
			"endpoint", config.S3Endpoint,
			"prefix", config.S3Prefix,
			"credential_source", "AWS SDK default chain (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, IAM, etc.)",
		)
	}
}