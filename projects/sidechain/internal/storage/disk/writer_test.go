package disk

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"
	
	"github.com/spf13/afero"
	
	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

func TestWriter_Write(t *testing.T) {
	fs := afero.NewMemMapFs()
	provider, err := New("/test", WithFS(fs))
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	
	writer, err := provider.NewTrackWriter("test-track")
	if err != nil {
		t.Fatalf("Failed to create writer: %v", err)
	}
	defer writer.Close()
	
	ctx := context.Background()
	
	// Test writing multiple events
	events := []indexer.Event{
		{
			Epoch:     1234567890,
			Height:    100,
			TxIndex:   1,
			EventType: "transfer",
			PkgPath:   "gno.land/r/demo/boards",
			Timestamp: time.Now().Unix(),
			Attrs: []indexer.EventAttribute{
				{Key: "from", Value: "addr1"},
				{Key: "to", Value: "addr2"},
				{Key: "amount", Value: "100"},
			},
		},
		{
			Epoch:     1234567890,
			Height:    101,
			TxIndex:   0,
			EventType: "mint",
			PkgPath:   "gno.land/r/demo/boards",
			Timestamp: time.Now().Unix(),
			Attrs: []indexer.EventAttribute{
				{Key: "to", Value: "addr3"},
				{Key: "amount", Value: "500"},
			},
		},
	}
	
	for _, event := range events {
		if err := writer.Write(ctx, event); err != nil {
			t.Fatalf("Failed to write event: %v", err)
		}
	}
	
	// Verify state is updated
	state := writer.state.GetState()
	if state.LastProcessedHeight != 101 {
		t.Errorf("LastProcessedHeight = %d, want 101", state.LastProcessedHeight)
	}
	if state.EventsRecorded != 2 {
		t.Errorf("EventsRecorded = %d, want 2", state.EventsRecorded)
	}
}

func TestWriter_EpochChange(t *testing.T) {
	fs := afero.NewMemMapFs()
	provider, err := New("/test", WithFS(fs))
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	
	writer, err := provider.NewTrackWriter("test-track")
	if err != nil {
		t.Fatalf("Failed to create writer: %v", err)
	}
	defer writer.Close()
	
	ctx := context.Background()
	
	// Write event with first epoch
	event1 := indexer.Event{
		Epoch:     1234567890,
		Height:    100,
		TxIndex:   1,
		EventType: "test",
		PkgPath:   "gno.land/p/test",
		Timestamp: time.Now().Unix(),
	}
	
	if err := writer.Write(ctx, event1); err != nil {
		t.Fatalf("Failed to write first event: %v", err)
	}
	
	// Verify first epoch directory exists
	epochDir1 := "/test/test-track/1234567890"
	exists, _ := afero.DirExists(fs, epochDir1)
	if !exists {
		t.Error("First epoch directory should exist")
	}
	
	// Write event with different epoch (simulating chain reset)
	event2 := indexer.Event{
		Epoch:     9876543210,
		Height:    1,  // Reset to block 1
		TxIndex:   0,
		EventType: "test",
		PkgPath:   "gno.land/p/test",
		Timestamp: time.Now().Unix(),
	}
	
	if err := writer.Write(ctx, event2); err != nil {
		t.Fatalf("Failed to write second event: %v", err)
	}
	
	// Verify second epoch directory exists
	epochDir2 := "/test/test-track/9876543210"
	exists, _ = afero.DirExists(fs, epochDir2)
	if !exists {
		t.Error("Second epoch directory should exist")
	}
	
	// Verify state was reset
	state := writer.state.GetState()
	if state.Epoch != 9876543210 {
		t.Errorf("Epoch = %d, want 9876543210", state.Epoch)
	}
	if state.LastProcessedHeight != 1 {
		t.Errorf("LastProcessedHeight = %d, want 1 (should reset)", state.LastProcessedHeight)
	}
	if state.EventsRecorded != 1 {
		t.Errorf("EventsRecorded = %d, want 1 (should reset)", state.EventsRecorded)
	}
}

func TestWriter_FileRotation(t *testing.T) {
	fs := afero.NewMemMapFs()
	
	// Use very short flush interval for testing
	provider, err := New("/test",
		WithFS(fs),
		WithFlushInterval(100*time.Millisecond),
		WithFlushSize(1), // Flush after each event
	)
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	
	writer, err := provider.NewTrackWriter("test-track")
	if err != nil {
		t.Fatalf("Failed to create writer: %v", err)
	}
	defer writer.Close()
	
	ctx := context.Background()
	currentHour := time.Now().Format("2006-01-02-15")
	
	// Write multiple events
	for i := 0; i < 5; i++ {
		event := indexer.Event{
			Epoch:     1234567890,
			Height:    int64(100 + i),
			TxIndex:   int64(i),
			EventType: "test",
			PkgPath:   "gno.land/p/test",
			Timestamp: time.Now().Unix(),
		}
		
		if err := writer.Write(ctx, event); err != nil {
			t.Fatalf("Failed to write event %d: %v", i, err)
		}
		
		// Small delay to ensure flush happens
		time.Sleep(150 * time.Millisecond)
	}
	
	// Force flush by closing
	writer.jsonl.Flush()
	
	// Check that the file exists and contains events
	filePath := fmt.Sprintf("/test/test-track/1234567890/%s.jsonl", currentHour)
	data, err := afero.ReadFile(fs, filePath)
	if err != nil {
		t.Fatalf("Failed to read JSONL file: %v", err)
	}
	
	// Count lines (each event is one line)
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != 5 {
		t.Errorf("Expected 5 events in file, got %d", len(lines))
	}
	
	// Verify each line is valid JSON
	for i, line := range lines {
		var event indexer.Event
		if err := json.Unmarshal([]byte(line), &event); err != nil {
			t.Errorf("Line %d is not valid JSON: %v", i, err)
		}
	}
}

func TestWriter_ConcurrentWrites(t *testing.T) {
	fs := afero.NewMemMapFs()
	provider, err := New("/test", WithFS(fs))
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	
	writer, err := provider.NewTrackWriter("test-track")
	if err != nil {
		t.Fatalf("Failed to create writer: %v", err)
	}
	defer writer.Close()
	
	ctx := context.Background()
	
	// Test concurrent writes (Writer should handle synchronization)
	done := make(chan error, 10)
	
	for i := 0; i < 10; i++ {
		go func(index int) {
			event := indexer.Event{
				Epoch:     1234567890,
				Height:    int64(100 + index),
				TxIndex:   int64(index),
				EventType: "concurrent",
				PkgPath:   "gno.land/p/test",
				Timestamp: time.Now().Unix(),
			}
			done <- writer.Write(ctx, event)
		}(i)
	}
	
	// Wait for all writes to complete
	for i := 0; i < 10; i++ {
		if err := <-done; err != nil {
			t.Errorf("Concurrent write %d failed: %v", i, err)
		}
	}
	
	// Verify all events were recorded
	state := writer.state.GetState()
	if state.EventsRecorded != 10 {
		t.Errorf("EventsRecorded = %d, want 10", state.EventsRecorded)
	}
}