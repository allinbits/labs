package disk

import (
	"encoding/json"
	"testing"
	
	"github.com/spf13/afero"
)

func TestStateManager_LoadSave(t *testing.T) {
	fs := afero.NewMemMapFs()
	sm := &StateManager{
		fs:       fs,
		basePath: "/test",
		trackID:  "test-track",
		state: TrackState{
			TrackID: "test-track",
			Epoch:   0,
		},
	}
	
	// Initial load (no file exists)
	if err := sm.Load(); err != nil {
		t.Fatalf("Load() failed on non-existent file: %v", err)
	}
	
	// State should be initialized
	if sm.state.TrackID != "test-track" {
		t.Errorf("TrackID = %s, want test-track", sm.state.TrackID)
	}
	if sm.state.Epoch != 0 {
		t.Errorf("Epoch = %d, want 0", sm.state.Epoch)
	}
	
	// Update state
	sm.state.Epoch = 1234567890
	sm.state.LastProcessedHeight = 100
	sm.state.LastProcessedTx = 5
	sm.state.EventsRecorded = 50
	
	// Save state
	if err := sm.Save(); err != nil {
		t.Fatalf("Save() failed: %v", err)
	}
	
	// Verify file was created
	statePath := "/test/test-track/state/state.json"
	exists, _ := afero.Exists(fs, statePath)
	if !exists {
		t.Error("State file should exist after save")
	}
	
	// Read and verify file contents
	data, err := afero.ReadFile(fs, statePath)
	if err != nil {
		t.Fatalf("Failed to read state file: %v", err)
	}
	
	var savedState TrackState
	if err := json.Unmarshal(data, &savedState); err != nil {
		t.Fatalf("Failed to unmarshal state: %v", err)
	}
	
	if savedState.Epoch != 1234567890 {
		t.Errorf("Saved Epoch = %d, want 1234567890", savedState.Epoch)
	}
	if savedState.LastProcessedHeight != 100 {
		t.Errorf("Saved LastProcessedHeight = %d, want 100", savedState.LastProcessedHeight)
	}
	if savedState.EventsRecorded != 50 {
		t.Errorf("Saved EventsRecorded = %d, want 50", savedState.EventsRecorded)
	}
	
	// Create new state manager and load
	sm2 := &StateManager{
		fs:       fs,
		basePath: "/test",
		trackID:  "test-track",
		state: TrackState{
			TrackID: "test-track",
		},
	}
	
	if err := sm2.Load(); err != nil {
		t.Fatalf("Load() failed on existing file: %v", err)
	}
	
	// Verify loaded state
	if sm2.state.Epoch != 1234567890 {
		t.Errorf("Loaded Epoch = %d, want 1234567890", sm2.state.Epoch)
	}
	if sm2.state.LastProcessedHeight != 100 {
		t.Errorf("Loaded LastProcessedHeight = %d, want 100", sm2.state.LastProcessedHeight)
	}
}

func TestStateManager_SetEpochIfNeeded(t *testing.T) {
	fs := afero.NewMemMapFs()
	sm := &StateManager{
		fs:       fs,
		basePath: "/test",
		trackID:  "test-track",
		state: TrackState{
			TrackID:             "test-track",
			Epoch:               1234567890,
			LastProcessedHeight: 100,
			LastProcessedTx:     5,
			EventsRecorded:      50,
		},
	}
	
	// Same epoch - no change
	changed, err := sm.SetEpochIfNeeded(1234567890)
	if err != nil {
		t.Fatalf("SetEpochIfNeeded() failed: %v", err)
	}
	if changed {
		t.Error("SetEpochIfNeeded() should return false for same epoch")
	}
	if sm.state.LastProcessedHeight != 100 {
		t.Error("State should not be reset for same epoch")
	}
	
	// Different epoch - should reset
	changed, err = sm.SetEpochIfNeeded(9876543210)
	if err != nil {
		t.Fatalf("SetEpochIfNeeded() failed: %v", err)
	}
	if !changed {
		t.Error("SetEpochIfNeeded() should return true for different epoch")
	}
	
	// Verify state was reset
	if sm.state.Epoch != 9876543210 {
		t.Errorf("Epoch = %d, want 9876543210", sm.state.Epoch)
	}
	if sm.state.LastProcessedHeight != 0 {
		t.Errorf("LastProcessedHeight = %d, want 0 (reset)", sm.state.LastProcessedHeight)
	}
	if sm.state.LastProcessedTx != 0 {
		t.Errorf("LastProcessedTx = %d, want 0 (reset)", sm.state.LastProcessedTx)
	}
	if sm.state.EventsRecorded != 0 {
		t.Errorf("EventsRecorded = %d, want 0 (reset)", sm.state.EventsRecorded)
	}
}

func TestStateManager_UpdatePosition(t *testing.T) {
	fs := afero.NewMemMapFs()
	sm := &StateManager{
		fs:       fs,
		basePath: "/test",
		trackID:  "test-track",
		state: TrackState{
			TrackID: "test-track",
		},
	}
	
	// Update position
	if err := sm.UpdatePosition(100, 5); err != nil {
		t.Fatalf("UpdatePosition() failed: %v", err)
	}
	
	if sm.state.LastProcessedHeight != 100 {
		t.Errorf("LastProcessedHeight = %d, want 100", sm.state.LastProcessedHeight)
	}
	if sm.state.LastProcessedTx != 5 {
		t.Errorf("LastProcessedTx = %d, want 5", sm.state.LastProcessedTx)
	}
	
	// Increment events and check auto-save behavior
	for i := 0; i < 99; i++ {
		sm.IncrementEventsRecorded()
	}
	
	// 99 events - no auto-save yet
	if err := sm.UpdatePosition(150, 7); err != nil {
		t.Fatalf("UpdatePosition() failed: %v", err)
	}
	
	statePath := "/test/test-track/state/state.json"
	exists, _ := afero.Exists(fs, statePath)
	if exists {
		t.Error("State file should not exist before 100 events")
	}
	
	// 100th event triggers auto-save
	sm.IncrementEventsRecorded()
	if err := sm.UpdatePosition(200, 10); err != nil {
		t.Fatalf("UpdatePosition() failed on auto-save: %v", err)
	}
	
	exists, _ = afero.Exists(fs, statePath)
	if !exists {
		t.Error("State file should exist after 100 events")
	}
	
	// Verify saved state
	data, _ := afero.ReadFile(fs, statePath)
	var savedState TrackState
	json.Unmarshal(data, &savedState)
	
	if savedState.EventsRecorded != 100 {
		t.Errorf("Saved EventsRecorded = %d, want 100", savedState.EventsRecorded)
	}
}

func TestStateManager_GetState(t *testing.T) {
	sm := &StateManager{
		state: TrackState{
			TrackID:             "test-track",
			Epoch:               1234567890,
			LastProcessedHeight: 100,
			LastProcessedTx:     5,
			EventsRecorded:      50,
		},
	}
	
	// GetState should return a copy
	state1 := sm.GetState()
	
	// Verify values
	if state1.TrackID != "test-track" {
		t.Errorf("TrackID = %s, want test-track", state1.TrackID)
	}
	if state1.Epoch != 1234567890 {
		t.Errorf("Epoch = %d, want 1234567890", state1.Epoch)
	}
	
	// Modifying returned state shouldn't affect internal state
	state1.EventsRecorded = 999
	state3 := sm.GetState()
	if state3.EventsRecorded != 50 {
		t.Error("GetState() should return a copy, not a reference")
	}
}