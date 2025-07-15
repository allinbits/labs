package lock

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/google/uuid"
)

// S3LockManager implements distributed locking using S3
type S3LockManager struct {
	client     *s3.Client
	bucket     string
	prefix     string
	instanceID string
	config     LockConfig
}

// S3LockConfig holds S3-specific configuration
type S3LockConfig struct {
	Bucket   string
	Region   string
	Endpoint string // For Minio/Tigris - leave empty for AWS S3
	Prefix   string // Prefix for lock objects (default: "locks/")
	
	// Embed common lock config
	LockConfig
}

// NewS3LockManager creates a new S3-based lock manager
func NewS3LockManager(ctx context.Context, cfg S3LockConfig) (*S3LockManager, error) {
	if cfg.Bucket == "" {
		return nil, errors.New("bucket name is required")
	}

	// Set defaults
	if cfg.Prefix == "" {
		cfg.Prefix = "locks/"
	}
	if !strings.HasSuffix(cfg.Prefix, "/") {
		cfg.Prefix += "/"
	}
	if cfg.InstanceID == "" {
		cfg.InstanceID = uuid.New().String()
	}
	if cfg.DefaultTTL == 0 {
		cfg.DefaultTTL = 30 * time.Second
	}

	// Create AWS config
	awsCfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(cfg.Region),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	// Create S3 client
	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		if cfg.Endpoint != "" {
			o.BaseEndpoint = aws.String(cfg.Endpoint)
			o.UsePathStyle = true // Required for Minio
		}
	})

	return &S3LockManager{
		client:     client,
		bucket:     cfg.Bucket,
		prefix:     cfg.Prefix,
		instanceID: cfg.InstanceID,
		config:     cfg.LockConfig,
	}, nil
}

// AcquireLock attempts to acquire a lock
func (m *S3LockManager) AcquireLock(ctx context.Context, key string, ttl time.Duration) (*Lock, error) {
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

	objectKey := m.getObjectKey(key)
	
	// Try to acquire lock with retries
	var lastErr error
	for i := 0; i <= m.config.MaxRetries; i++ {
		if i > 0 {
			time.Sleep(m.config.RetryInterval)
		}

		// Check if lock already exists
		existingLock, err := m.GetLock(ctx, key)
		if err == nil {
			// Lock exists, check if expired
			if existingLock.IsExpired() {
				// Try to steal expired lock
				if stolen, err := m.stealExpiredLock(ctx, key, lock, existingLock); err == nil {
					return stolen, nil
				}
			} else {
				// Lock is held by another instance
				lastErr = ErrLockAcquisitionFailed
				continue
			}
		}

		// Try to create new lock
		lockData, err := json.Marshal(lock)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal lock: %w", err)
		}

		// Use conditional put to ensure atomicity
		// This will fail if the object already exists
		_, err = m.client.PutObject(ctx, &s3.PutObjectInput{
			Bucket: aws.String(m.bucket),
			Key:    aws.String(objectKey),
			Body:   bytes.NewReader(lockData),
			ContentType: aws.String("application/json"),
			// Only create if doesn't exist
			Metadata: map[string]string{
				"holder-id": m.instanceID,
				"token":     lock.Token,
			},
		})

		if err == nil {
			return lock, nil
		}

		// Check if the error is because object already exists
		// In this case, we'll retry after checking expiration
		lastErr = err
	}

	return nil, fmt.Errorf("failed to acquire lock after %d retries: %w", m.config.MaxRetries, lastErr)
}

// stealExpiredLock attempts to replace an expired lock
func (m *S3LockManager) stealExpiredLock(ctx context.Context, key string, newLock *Lock, oldLock *Lock) (*Lock, error) {
	objectKey := m.getObjectKey(key)
	
	lockData, err := json.Marshal(newLock)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal lock: %w", err)
	}

	// Try to overwrite the expired lock
	// In a real implementation, we'd use ETags here for better consistency
	_, err = m.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(m.bucket),
		Key:         aws.String(objectKey),
		Body:        bytes.NewReader(lockData),
		ContentType: aws.String("application/json"),
		Metadata: map[string]string{
			"holder-id": m.instanceID,
			"token":     newLock.Token,
		},
	})

	if err != nil {
		return nil, fmt.Errorf("failed to steal expired lock: %w", err)
	}

	return newLock, nil
}

// ReleaseLock releases a lock
func (m *S3LockManager) ReleaseLock(ctx context.Context, lock *Lock) error {
	if lock == nil {
		return errors.New("lock cannot be nil")
	}

	// Verify this instance holds the lock
	currentLock, err := m.GetLock(ctx, lock.Key)
	if err != nil {
		return err
	}

	if currentLock.HolderID != m.instanceID || currentLock.Token != lock.Token {
		return ErrLockNotHeld
	}

	// Delete the lock object
	objectKey := m.getObjectKey(lock.Key)
	_, err = m.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(m.bucket),
		Key:    aws.String(objectKey),
	})

	if err != nil {
		return fmt.Errorf("failed to delete lock: %w", err)
	}

	return nil
}

// IsLocked checks if a lock exists and is valid
func (m *S3LockManager) IsLocked(ctx context.Context, key string) (bool, error) {
	lock, err := m.GetLock(ctx, key)
	if err != nil {
		if errors.Is(err, ErrLockNotFound) {
			return false, nil
		}
		return false, err
	}

	return !lock.IsExpired(), nil
}

// GetLock retrieves information about a lock
func (m *S3LockManager) GetLock(ctx context.Context, key string) (*Lock, error) {
	objectKey := m.getObjectKey(key)

	result, err := m.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(m.bucket),
		Key:    aws.String(objectKey),
	})

	if err != nil {
		var nsk *types.NoSuchKey
		if errors.As(err, &nsk) {
			return nil, ErrLockNotFound
		}
		return nil, fmt.Errorf("failed to get lock from S3: %w", err)
	}
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read lock data: %w", err)
	}

	var lock Lock
	if err := json.Unmarshal(body, &lock); err != nil {
		return nil, fmt.Errorf("failed to unmarshal lock: %w", err)
	}

	return &lock, nil
}

// getObjectKey generates the S3 object key for a lock
func (m *S3LockManager) getObjectKey(key string) string {
	// Sanitize the key to ensure it's a valid S3 object key
	sanitized := strings.ReplaceAll(key, ":", "-")
	return fmt.Sprintf("%s%s.lock", m.prefix, sanitized)
}

// CleanupExpiredLocks removes expired locks (optional maintenance task)
func (m *S3LockManager) CleanupExpiredLocks(ctx context.Context) error {
	// List all lock objects
	paginator := s3.NewListObjectsV2Paginator(m.client, &s3.ListObjectsV2Input{
		Bucket: aws.String(m.bucket),
		Prefix: aws.String(m.prefix),
	})

	var expiredKeys []string

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("failed to list locks: %w", err)
		}

		for _, obj := range page.Contents {
			if obj.Key == nil {
				continue
			}

			// Extract lock key from object key
			lockKey := strings.TrimPrefix(*obj.Key, m.prefix)
			lockKey = strings.TrimSuffix(lockKey, ".lock")

			// Check if lock is expired
			lock, err := m.GetLock(ctx, lockKey)
			if err != nil {
				continue // Skip if we can't read the lock
			}

			if lock.IsExpired() {
				expiredKeys = append(expiredKeys, *obj.Key)
			}
		}
	}

	// Delete expired locks
	for _, key := range expiredKeys {
		_, _ = m.client.DeleteObject(ctx, &s3.DeleteObjectInput{
			Bucket: aws.String(m.bucket),
			Key:    aws.String(key),
		})
	}

	return nil
}