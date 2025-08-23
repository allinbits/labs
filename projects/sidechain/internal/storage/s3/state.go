package s3

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"path"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go"
)

// TrackState represents the persistent state of a track
type TrackState struct {
	TrackID             string `json:"track_id"`
	Epoch               int64  `json:"epoch"`
	LastProcessedHeight int64  `json:"last_processed_height"`
	LastProcessedTx     int64  `json:"last_processed_tx"`
	LastUpdate          int64  `json:"last_update"`
	EventsRecorded      int64  `json:"events_recorded"`
}

// StateManager handles reading and writing track state to S3
type StateManager struct {
	client  Client
	bucket  string
	prefix  string
	trackID string

	mu    sync.RWMutex
	state TrackState
}

// Load reads the state from S3 if it exists
func (sm *StateManager) Load(ctx context.Context) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	key := sm.getStateKey()

	// Try to get existing state from S3
	result, err := sm.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(sm.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		// Check if it's a not found error
		var apiErr smithy.APIError
		if errors.As(err, &apiErr) {
			if apiErr.ErrorCode() == "NoSuchKey" {
				// State doesn't exist yet, that's ok
				return nil
			}
		}
		return fmt.Errorf("failed to get state from S3: %w", err)
	}
	defer result.Body.Close()

	// Read and unmarshal state
	data, err := io.ReadAll(result.Body)
	if err != nil {
		return fmt.Errorf("failed to read state: %w", err)
	}

	if err := json.Unmarshal(data, &sm.state); err != nil {
		return fmt.Errorf("failed to unmarshal state: %w", err)
	}

	// Ensure trackID matches
	sm.state.TrackID = sm.trackID

	return nil
}

// Save writes the current state to S3
func (sm *StateManager) Save(ctx context.Context) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	return sm.save(ctx)
}

// save performs the actual save (must be called with lock held)
func (sm *StateManager) save(ctx context.Context) error {
	sm.state.LastUpdate = time.Now().Unix()

	// Marshal state
	data, err := json.MarshalIndent(sm.state, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal state: %w", err)
	}

	key := sm.getStateKey()

	// Write to S3
	_, err = sm.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(sm.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("application/json"),
	})
	if err != nil {
		return fmt.Errorf("failed to write state to S3: %w", err)
	}

	return nil
}

// GetState returns a copy of the current state
func (sm *StateManager) GetState() TrackState {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.state
}

// UpdatePosition updates the last processed position
func (sm *StateManager) UpdatePosition(ctx context.Context, height, txIndex int64) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	sm.state.LastProcessedHeight = height
	sm.state.LastProcessedTx = txIndex

	// Auto-save periodically (every 100 events)
	if sm.state.EventsRecorded > 0 && sm.state.EventsRecorded%100 == 0 {
		return sm.save(ctx)
	}

	return nil
}

// SetEpochIfNeeded updates the epoch if it's different from current
func (sm *StateManager) SetEpochIfNeeded(ctx context.Context, epoch int64) (bool, error) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if sm.state.Epoch == epoch {
		return false, nil // No change
	}

	// Epoch changed - reset position
	sm.state.Epoch = epoch
	sm.state.LastProcessedHeight = 0
	sm.state.LastProcessedTx = 0
	sm.state.EventsRecorded = 0

	// Save immediately on epoch change
	if err := sm.save(ctx); err != nil {
		return true, err
	}

	return true, nil
}

// IncrementEventsRecorded increments the events counter
func (sm *StateManager) IncrementEventsRecorded() {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.state.EventsRecorded++
}

// getStateKey returns the S3 key for the state file
func (sm *StateManager) getStateKey() string {
	key := fmt.Sprintf("%s/state.json", sm.trackID)

	if sm.prefix != "" {
		key = path.Join(sm.prefix, key)
	}

	return key
}
