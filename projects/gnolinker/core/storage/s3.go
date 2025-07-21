package storage

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
)

// S3ConfigStore provides an S3-compatible implementation of ConfigStore
// Compatible with AWS S3, Minio, and Tigris Data
type S3ConfigStore struct {
	client *s3.Client
	bucket string
	prefix string // Optional prefix for object keys
}

// S3Config holds the configuration for S3-compatible storage
type S3Config struct {
	Bucket   string
	Region   string
	Endpoint string // For Minio/Tigris - leave empty for AWS S3
	Prefix   string // Optional prefix for object keys (e.g., "configs/")
	// Note: AccessKeyID, SecretAccessKey, and UseSSL removed - AWS SDK handles these automatically
}

// NewS3ConfigStore creates a new S3-compatible config store
func NewS3ConfigStore(ctx context.Context, cfg S3Config) (*S3ConfigStore, error) {
	if cfg.Bucket == "" {
		return nil, errors.New("bucket name is required")
	}

	// Always use AWS default credential chain (environment, IAM, shared credentials, etc.)
	awsCfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(cfg.Region),
	)
	
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	// Create S3 client with custom endpoint for Minio/Tigris
	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		if cfg.Endpoint != "" {
			o.BaseEndpoint = aws.String(cfg.Endpoint)
			o.UsePathStyle = true // Required for Minio
		}
	})

	// Ensure prefix ends with "/" if provided
	prefix := cfg.Prefix
	if prefix != "" && !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}

	return &S3ConfigStore{
		client: client,
		bucket: cfg.Bucket,
		prefix: prefix,
	}, nil
}

// Get retrieves a guild configuration by guild ID
func (s *S3ConfigStore) Get(guildID string) (*GuildConfig, error) {
	key := s.getObjectKey(guildID)
	
	ctx := context.Background()
	result, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	
	if err != nil {
		var nsk *types.NoSuchKey
		if errors.As(err, &nsk) {
			return nil, ErrGuildConfigNotFound
		}
		return nil, fmt.Errorf("failed to get object from S3: %w", err)
	}
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	var config GuildConfig
	if err := json.Unmarshal(body, &config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Store ETag for optimistic concurrency control
	if result.ETag != nil {
		config.ETag = *result.ETag
	}

	return &config, nil
}

// Set stores a guild configuration
func (s *S3ConfigStore) Set(guildID string, config *GuildConfig) error {
	if config == nil {
		return errors.New("config cannot be nil")
	}

	data, err := json.Marshal(config)
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	key := s.getObjectKey(guildID)
	
	ctx := context.Background()
	putInput := &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("application/json"),
	}

	// Use conditional put if ETag is provided for optimistic concurrency control
	if config.ETag != "" {
		putInput.IfMatch = aws.String(config.ETag)
	}

	_, err = s.client.PutObject(ctx, putInput)
	
	if err != nil {
		// Check for precondition failed (ETag mismatch) - AWS returns 412 status code
		if strings.Contains(err.Error(), "PreconditionFailed") || strings.Contains(err.Error(), "412") {
			return ErrConcurrencyConflict
		}
		return fmt.Errorf("failed to put object to S3: %w", err)
	}

	return nil
}

// Delete removes a guild configuration
func (s *S3ConfigStore) Delete(guildID string) error {
	key := s.getObjectKey(guildID)
	
	ctx := context.Background()
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	
	if err != nil {
		return fmt.Errorf("failed to delete object from S3: %w", err)
	}

	return nil
}

// GetGlobal retrieves the global configuration
func (s *S3ConfigStore) GetGlobal() (*GlobalConfig, error) {
	key := s.getGlobalObjectKey()
	
	ctx := context.Background()
	result, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	
	if err != nil {
		var nsk *types.NoSuchKey
		if errors.As(err, &nsk) {
			// Return default global config if none exists
			return &GlobalConfig{
				ConfigID:                 "global",
				LastProcessedBlockHeight: 0,
				LastUpdated:              time.Now(),
			}, nil
		}
		return nil, fmt.Errorf("failed to get global config from S3: %w", err)
	}
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read global config response body: %w", err)
	}

	var config GlobalConfig
	if err := json.Unmarshal(body, &config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal global config: %w", err)
	}

	// Store ETag for optimistic concurrency control
	if result.ETag != nil {
		config.ETag = *result.ETag
	}

	return &config, nil
}

// SetGlobal stores the global configuration
func (s *S3ConfigStore) SetGlobal(config *GlobalConfig) error {
	if config == nil {
		return errors.New("global config cannot be nil")
	}

	data, err := json.Marshal(config)
	if err != nil {
		return fmt.Errorf("failed to marshal global config: %w", err)
	}

	key := s.getGlobalObjectKey()
	
	ctx := context.Background()
	putInput := &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("application/json"),
	}

	// Use conditional put if ETag is provided for optimistic concurrency control
	if config.ETag != "" {
		putInput.IfMatch = aws.String(config.ETag)
	}

	_, err = s.client.PutObject(ctx, putInput)
	
	if err != nil {
		// Check for precondition failed (ETag mismatch) - AWS returns 412 status code
		if strings.Contains(err.Error(), "PreconditionFailed") || strings.Contains(err.Error(), "412") {
			return ErrConcurrencyConflict
		}
		return fmt.Errorf("failed to put global config to S3: %w", err)
	}

	return nil
}

// getObjectKey generates the S3 object key for a guild ID
func (s *S3ConfigStore) getObjectKey(guildID string) string {
	return fmt.Sprintf("%s%s.json", s.prefix, guildID)
}

// getGlobalObjectKey generates the S3 object key for global config
func (s *S3ConfigStore) getGlobalObjectKey() string {
	return fmt.Sprintf("%sglobal.json", s.prefix)
}

// EnsureBucket creates the bucket if it doesn't exist (useful for Minio setup)
func (s *S3ConfigStore) EnsureBucket(ctx context.Context) error {
	// Check if bucket exists
	_, err := s.client.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: aws.String(s.bucket),
	})
	
	if err == nil {
		return nil // Bucket already exists
	}

	// Try to create the bucket
	_, err = s.client.CreateBucket(ctx, &s3.CreateBucketInput{
		Bucket: aws.String(s.bucket),
	})
	
	if err != nil {
		return fmt.Errorf("failed to create bucket: %w", err)
	}

	return nil
}

// HealthCheck verifies connectivity and access to the S3 bucket
func (s *S3ConfigStore) HealthCheck(ctx context.Context) error {
	// Test bucket access
	_, err := s.client.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: aws.String(s.bucket),
	})
	
	if err != nil {
		return fmt.Errorf("bucket health check failed: %w", err)
	}

	// Test write/read/delete cycle with a test object
	testKey := s.getObjectKey("__health_check__")
	testData := []byte(`{"test": true}`)
	
	// Test write
	_, err = s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(testKey),
		Body:        bytes.NewReader(testData),
		ContentType: aws.String("application/json"),
	})
	
	if err != nil {
		return fmt.Errorf("write test failed: %w", err)
	}

	// Test read
	result, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(testKey),
	})
	
	if err != nil {
		return fmt.Errorf("read test failed: %w", err)
	}
	if err := result.Body.Close(); err != nil {
		return fmt.Errorf("failed to close response body: %w", err)
	}

	// Test delete
	_, err = s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(testKey),
	})
	
	if err != nil {
		return fmt.Errorf("delete test failed: %w", err)
	}

	return nil
}