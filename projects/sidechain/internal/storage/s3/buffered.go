package s3

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"path"
	"sync"
	"time"
	
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	
	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

// BufferedWriter buffers events and periodically flushes them to S3
type BufferedWriter struct {
	client        S3API
	bucket        string
	prefix        string
	trackID       string
	currentEpoch  int64
	bufferTimeout time.Duration
	
	mu           sync.Mutex
	buffer       []byte
	eventCount   int
	lastFlush    time.Time
	currentHour  string
	flushTimer   *time.Timer
}

// startFlushTimer starts the periodic flush timer
func (bw *BufferedWriter) startFlushTimer() {
	bw.mu.Lock()
	defer bw.mu.Unlock()
	
	if bw.flushTimer != nil {
		bw.flushTimer.Stop()
	}
	
	bw.flushTimer = time.AfterFunc(bw.bufferTimeout, func() {
		ctx := context.Background()
		bw.Flush(ctx)
		bw.startFlushTimer() // Restart timer
	})
}

// WriteEvent adds an event to the buffer
func (bw *BufferedWriter) WriteEvent(ctx context.Context, event indexer.Event) error {
	bw.mu.Lock()
	defer bw.mu.Unlock()
	
	// Validate event
	if err := bw.validateEvent(event); err != nil {
		return fmt.Errorf("invalid event: %w", err)
	}
	
	// Marshal event to JSON
	data, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}
	
	// Add to buffer with newline
	bw.buffer = append(bw.buffer, data...)
	bw.buffer = append(bw.buffer, '\n')
	bw.eventCount++
	
	// Check if we should flush (buffer size > 5MB or hour changed)
	currentHour := time.Now().Format("2006-01-02-15")
	if len(bw.buffer) > 5*1024*1024 || (bw.currentHour != "" && bw.currentHour != currentHour) {
		return bw.flush(ctx)
	}
	
	bw.currentHour = currentHour
	return nil
}

// SetEpoch updates the epoch for the writer
func (bw *BufferedWriter) SetEpoch(epoch int64) {
	bw.mu.Lock()
	defer bw.mu.Unlock()
	bw.currentEpoch = epoch
}

// Flush writes the buffer to S3
func (bw *BufferedWriter) Flush(ctx context.Context) error {
	bw.mu.Lock()
	defer bw.mu.Unlock()
	return bw.flush(ctx)
}

// flush performs the actual flush (must be called with lock held)
func (bw *BufferedWriter) flush(ctx context.Context) error {
	if len(bw.buffer) == 0 {
		return nil // Nothing to flush
	}
	
	// Generate S3 key
	key := bw.generateKey()
	
	// Upload to S3
	_, err := bw.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bw.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(bw.buffer),
		ContentType: aws.String("application/x-ndjson"),
	})
	if err != nil {
		return fmt.Errorf("failed to upload to S3: %w", err)
	}
	
	// Clear buffer
	bw.buffer = bw.buffer[:0]
	bw.eventCount = 0
	bw.lastFlush = time.Now()
	
	return nil
}

// generateKey generates the S3 key for the current buffer
func (bw *BufferedWriter) generateKey() string {
	timestamp := time.Now()
	hour := timestamp.Format("2006-01-02-15")
	
	// Format: [prefix/]trackID/epoch/YYYY-MM-DD-HH/events-{timestamp}.jsonl
	keyPath := fmt.Sprintf("%s/%d/%s/events-%d.jsonl",
		bw.trackID,
		bw.currentEpoch,
		hour,
		timestamp.UnixNano(),
	)
	
	if bw.prefix != "" {
		keyPath = path.Join(bw.prefix, keyPath)
	}
	
	return keyPath
}

// validateEvent checks that the event has required fields
func (bw *BufferedWriter) validateEvent(event indexer.Event) error {
	if event.Epoch == 0 {
		return fmt.Errorf("event missing epoch")
	}
	if event.Height == 0 {
		return fmt.Errorf("event missing height")
	}
	if event.EventType == "" {
		return fmt.Errorf("event missing type")
	}
	if event.PkgPath == "" {
		return fmt.Errorf("event missing package path")
	}
	return nil
}

// Close flushes any remaining buffer and stops the timer
func (bw *BufferedWriter) Close(ctx context.Context) error {
	bw.mu.Lock()
	
	// Stop the flush timer
	if bw.flushTimer != nil {
		bw.flushTimer.Stop()
		bw.flushTimer = nil
	}
	
	// Flush any remaining data
	err := bw.flush(ctx)
	bw.mu.Unlock()
	
	return err
}