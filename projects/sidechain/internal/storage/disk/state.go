package disk

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
	
	"github.com/spf13/afero"
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

// StateManager handles reading and writing track state
// It owns the state completely - no external epoch parameters
type StateManager struct {
	fs       afero.Fs
	basePath string
	trackID  string
	
	mu    sync.RWMutex
	state TrackState
}

// NewStateManager creates a new state manager for a track
// Deprecated: Use Provider.NewTrackWriter instead
func NewStateManager(basePath, trackID string) *StateManager {
	return &StateManager{
		fs:       afero.NewOsFs(),
		basePath: basePath,
		trackID:  trackID,
		state: TrackState{
			TrackID: trackID,
			Epoch:   0, // Will be set from first event
		},
	}
}

// Load reads the state from disk if it exists, otherwise initializes new state
func (sm *StateManager) Load() error {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	
	statePath := sm.getStatePath()
	
	// Try to read existing state
	data, err := afero.ReadFile(sm.fs, statePath)
	if err != nil {
		// If file doesn't exist, that's ok - we'll use initial state
		if !isNotExist(err) {
			return fmt.Errorf("failed to read state file: %w", err)
		}
		// Keep initial state
		return nil
	}
	
	// Parse existing state
	if err := json.Unmarshal(data, &sm.state); err != nil {
		return fmt.Errorf("failed to unmarshal state: %w", err)
	}
	
	// Ensure trackID matches (in case of file corruption)
	sm.state.TrackID = sm.trackID
	
	return nil
}

// Save writes the current state to disk
func (sm *StateManager) Save() error {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	
	return sm.save()
}

// save performs the actual save (must be called with lock held)
func (sm *StateManager) save() error {
	sm.state.LastUpdate = time.Now().Unix()
	
	// Marshal state
	data, err := json.MarshalIndent(sm.state, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal state: %w", err)
	}
	
	// Ensure directory exists
	stateDir := filepath.Join(sm.basePath, sm.trackID, "state")
	if err := sm.fs.MkdirAll(stateDir, 0755); err != nil {
		return fmt.Errorf("failed to create state directory: %w", err)
	}
	
	// Write state file
	statePath := sm.getStatePath()
	if err := afero.WriteFile(sm.fs, statePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write state file: %w", err)
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
func (sm *StateManager) UpdatePosition(height, txIndex int64) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	
	sm.state.LastProcessedHeight = height
	sm.state.LastProcessedTx = txIndex
	
	// Auto-save periodically (every 100 events)
	if sm.state.EventsRecorded > 0 && sm.state.EventsRecorded%100 == 0 {
		return sm.save()
	}
	
	return nil
}

// SetEpochIfNeeded updates the epoch if it's different from current
func (sm *StateManager) SetEpochIfNeeded(epoch int64) (bool, error) {
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
	if err := sm.save(); err != nil {
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

// getStatePath returns the path to the state file
func (sm *StateManager) getStatePath() string {
	return filepath.Join(sm.basePath, sm.trackID, "state", "state.json")
}

// isNotExist checks if an error is a "not exists" error
// Works with both os and afero errors
func isNotExist(err error) bool {
	if err == nil {
		return false
	}
	// Use os.IsNotExist which works with afero
	return os.IsNotExist(err)
}