package s3

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// Provider implements storage.Provider using S3-compatible object storage
type Provider struct {
	client        Client
	bucket        string
	prefix        string
	region        string
	endpoint      string // Custom endpoint for MinIO, LocalStack, etc.
	bufferTimeout time.Duration
}

// Option configures a Provider
type Option func(*Provider)

// WithClient sets a custom S3 client (useful for testing)
func WithClient(client Client) Option {
	return func(p *Provider) {
		p.client = client
	}
}

// WithPrefix sets a key prefix for all objects
func WithPrefix(prefix string) Option {
	return func(p *Provider) {
		p.prefix = prefix
	}
}

// WithRegion sets the AWS region
func WithRegion(region string) Option {
	return func(p *Provider) {
		p.region = region
	}
}

// WithBufferTimeout sets how often to flush buffered events to S3
func WithBufferTimeout(timeout time.Duration) Option {
	return func(p *Provider) {
		p.bufferTimeout = timeout
	}
}

// WithEndpoint sets a custom endpoint (for MinIO, LocalStack, etc)
func WithEndpoint(endpoint string) Option {
	return func(p *Provider) {
		p.endpoint = endpoint
	}
}

// New creates a new S3 storage provider
func New(bucket string, opts ...Option) (*Provider, error) {
	if bucket == "" {
		return nil, fmt.Errorf("s3 storage requires a bucket name")
	}

	// Start with defaults
	p := &Provider{
		bucket:        bucket,
		region:        "us-east-1", // Default region
		bufferTimeout: 30 * time.Second,
	}

	// Apply options
	for _, opt := range opts {
		opt(p)
	}

	// Create S3 client if not provided
	if p.client == nil {
		var configOpts []func(*config.LoadOptions) error
		configOpts = append(configOpts, config.WithRegion(p.region))

		cfg, err := config.LoadDefaultConfig(context.Background(), configOpts...)
		if err != nil {
			return nil, fmt.Errorf("failed to load AWS config: %w", err)
		}

		// Create S3 client with custom endpoint if provided
		if p.endpoint != "" {
			p.client = s3.NewFromConfig(cfg, func(o *s3.Options) {
				o.BaseEndpoint = aws.String(p.endpoint)
				o.UsePathStyle = true // Required for MinIO and most S3-compatible services
			})
		} else {
			p.client = s3.NewFromConfig(cfg)
		}
	}

	// Verify bucket access
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := p.client.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: aws.String(p.bucket),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to access bucket %s: %w", p.bucket, err)
	}

	return p, nil
}

// NewTrackWriter creates a new track-specific writer
func (p *Provider) NewTrackWriter(trackID string) (*Writer, error) {
	// Create state manager (S3-backed)
	stateManager := &StateManager{
		client:  p.client,
		bucket:  p.bucket,
		prefix:  p.prefix,
		trackID: trackID,
		state: TrackState{
			TrackID: trackID,
			Epoch:   0, // Will be set from first event
		},
	}

	// Load existing state or initialize new
	stateManager.Load(context.Background())

	// Create buffered writer
	writer := &BufferedWriter{
		client:        p.client,
		bucket:        p.bucket,
		prefix:        p.prefix,
		trackID:       trackID,
		bufferTimeout: p.bufferTimeout,
		buffer:        make([]byte, 0, 1024*1024), // 1MB initial buffer
	}

	// Start the flush timer
	writer.startFlushTimer()

	// Create and return writer
	return &Writer{
		trackID:  trackID,
		buffered: writer,
		state:    stateManager,
	}, nil
}

// Close implements storage.Provider.Close
func (p *Provider) Close() error {
	// S3 client doesn't need explicit closing
	return nil
}
