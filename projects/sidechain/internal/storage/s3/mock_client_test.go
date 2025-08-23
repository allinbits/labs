package s3

import (
	"bytes"
	"context"
	"errors"
	"io"
	"sync"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"

	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

// MockClient implements Client for testing
type MockClient struct {
	mu      sync.Mutex
	objects map[string][]byte
	buckets map[string]bool
	
	// Control behavior
	HeadBucketErr error
	PutObjectErr  error
	GetObjectErr  error
}

func NewMockClient() *MockClient {
	return &MockClient{
		objects: make(map[string][]byte),
		buckets: map[string]bool{
			"test-bucket": true,
		},
	}
}

func (m *MockClient) HeadBucket(ctx context.Context, params *s3.HeadBucketInput, optFns ...func(*s3.Options)) (*s3.HeadBucketOutput, error) {
	if m.HeadBucketErr != nil {
		return nil, m.HeadBucketErr
	}
	
	m.mu.Lock()
	defer m.mu.Unlock()
	
	if !m.buckets[*params.Bucket] {
		return nil, &types.NotFound{}
	}
	return &s3.HeadBucketOutput{}, nil
}

func (m *MockClient) PutObject(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.Options)) (*s3.PutObjectOutput, error) {
	if m.PutObjectErr != nil {
		return nil, m.PutObjectErr
	}
	
	m.mu.Lock()
	defer m.mu.Unlock()
	
	data, err := io.ReadAll(params.Body)
	if err != nil {
		return nil, err
	}
	
	key := *params.Bucket + "/" + *params.Key
	m.objects[key] = data
	
	return &s3.PutObjectOutput{}, nil
}

func (m *MockClient) GetObject(ctx context.Context, params *s3.GetObjectInput, optFns ...func(*s3.Options)) (*s3.GetObjectOutput, error) {
	if m.GetObjectErr != nil {
		return nil, m.GetObjectErr
	}
	
	m.mu.Lock()
	defer m.mu.Unlock()
	
	key := *params.Bucket + "/" + *params.Key
	data, ok := m.objects[key]
	if !ok {
		return nil, &types.NoSuchKey{}
	}
	
	return &s3.GetObjectOutput{
		Body: io.NopCloser(bytes.NewReader(data)),
	}, nil
}

func TestProviderWithMockClient(t *testing.T) {
	mockClient := NewMockClient()
	
	provider, err := New("test-bucket",
		WithClient(mockClient),
	)
	if err != nil {
		t.Fatalf("failed to create provider: %v", err)
	}
	defer provider.Close()
	
	writer, err := provider.NewTrackWriter("test-track")
	if err != nil {
		t.Fatalf("failed to create writer: %v", err)
	}
	defer writer.Close()
	
	ctx := context.Background()
	event := indexer.Event{
		Epoch:     1,
		Height:    100,
		TxIndex:   1,
		EventType: "test",
		PkgPath:   "gno.land/r/test",
		Timestamp: 1234567890,
		Attrs: []indexer.EventAttribute{
			{Key: "action", Value: "create"},
		},
	}
	
	if err := writer.Write(ctx, event); err != nil {
		t.Fatalf("failed to write event: %v", err)
	}
	
	// Check that data was written to mock
	mockClient.mu.Lock()
	objectCount := len(mockClient.objects)
	mockClient.mu.Unlock()
	
	if objectCount == 0 {
		t.Error("no objects written to mock S3")
	}
}

func TestProviderBucketAccessError(t *testing.T) {
	mockClient := NewMockClient()
	mockClient.HeadBucketErr = errors.New("access denied")
	
	_, err := New("test-bucket",
		WithClient(mockClient),
	)
	if err == nil {
		t.Fatal("expected error for bucket access failure")
	}
	if err.Error() != "failed to access bucket test-bucket: access denied" {
		t.Fatalf("unexpected error: %v", err)
	}
}