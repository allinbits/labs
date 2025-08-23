package s3

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// Client defines the S3 operations we use
type Client interface {
	HeadBucket(ctx context.Context, params *s3.HeadBucketInput, optFns ...func(*s3.Options)) (*s3.HeadBucketOutput, error)
	PutObject(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.Options)) (*s3.PutObjectOutput, error)
	GetObject(ctx context.Context, params *s3.GetObjectInput, optFns ...func(*s3.Options)) (*s3.GetObjectOutput, error)
}

// Verify that *s3.Client implements Client
var _ Client = (*s3.Client)(nil)
