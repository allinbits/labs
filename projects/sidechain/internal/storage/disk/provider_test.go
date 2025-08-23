package disk

import (
	"context"
	"fmt"
	"testing"
	"time"
	
	"github.com/spf13/afero"
	
	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

func TestNew(t *testing.T) {
	tests := []struct {
		name    string
		path    string
		opts    []Option
		wantErr bool
	}{
		{
			name: "valid path with defaults",
			path: "/tmp/events",
		},
		{
			name:    "empty path",
			path:    "",
			wantErr: true,
		},
		{
			name: "with custom options",
			path: "/tmp/events",
			opts: []Option{
				WithFlushInterval(10 * time.Second),
				WithFlushSize(200),
			},
		},
		{
			name: "with mock filesystem",
			path: "/events",
			opts: []Option{
				WithFS(afero.NewMemMapFs()),
			},
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			provider, err := New(tt.path, tt.opts...)
			if (err != nil) != tt.wantErr {
				t.Errorf("New() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && provider == nil {
				t.Error("New() returned nil provider without error")
			}
		})
	}
}

func TestProvider_NewTrackWriter(t *testing.T) {
	// Use in-memory filesystem for testing
	fs := afero.NewMemMapFs()
	provider, err := New("/test", WithFS(fs))
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	
	// Test creating a new writer
	writer, err := provider.NewTrackWriter("test-track")
	if err != nil {
		t.Fatalf("NewTrackWriter() error = %v", err)
	}
	if writer == nil {
		t.Fatal("NewTrackWriter() returned nil writer")
	}
	
	// Test that state file doesn't exist initially (new track)
	statePath := "/test/test-track/state/state.json"
	exists, _ := afero.Exists(fs, statePath)
	if exists {
		t.Error("State file should not exist for new track")
	}
	
	// Write an event and close to trigger state save
	event := indexer.Event{
		Epoch:     1234567890,
		Height:    100,
		TxIndex:   1,
		EventType: "test",
		PkgPath:   "gno.land/p/test",
		Timestamp: time.Now().Unix(),
	}
	
	ctx := context.Background()
	if err := writer.Write(ctx, event); err != nil {
		t.Fatalf("Failed to write event: %v", err)
	}
	
	if err := writer.Close(); err != nil {
		t.Fatalf("Failed to close writer: %v", err)
	}
	
	// Now state file should exist
	exists, _ = afero.Exists(fs, statePath)
	if !exists {
		t.Error("State file should exist after closing writer")
	}
}

func TestProvider_MultipleWriters(t *testing.T) {
	fs := afero.NewMemMapFs()
	provider, err := New("/test", WithFS(fs))
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	
	// Create multiple writers for different tracks
	tracks := []string{"track1", "track2", "track3"}
	writers := make([]*Writer, 0, len(tracks))
	
	for _, track := range tracks {
		writer, err := provider.NewTrackWriter(track)
		if err != nil {
			t.Fatalf("Failed to create writer for %s: %v", track, err)
		}
		writers = append(writers, writer)
	}
	
	// Each writer should be independent
	if len(writers) != len(tracks) {
		t.Errorf("Expected %d writers, got %d", len(tracks), len(writers))
	}
	
	// Write different events to each track
	ctx := context.Background()
	for i, writer := range writers {
		event := indexer.Event{
			Epoch:     1234567890,
			Height:    int64(100 + i),
			TxIndex:   int64(i),
			EventType: "test",
			PkgPath:   "gno.land/p/test",
			Timestamp: time.Now().Unix(),
		}
		
		if err := writer.Write(ctx, event); err != nil {
			t.Fatalf("Failed to write to track %s: %v", tracks[i], err)
		}
		
		if err := writer.Close(); err != nil {
			t.Fatalf("Failed to close writer for track %s: %v", tracks[i], err)
		}
	}
	
	// Verify each track has its own directory
	for _, track := range tracks {
		trackDir := fmt.Sprintf("/test/%s", track)
		exists, _ := afero.DirExists(fs, trackDir)
		if !exists {
			t.Errorf("Directory for track %s should exist", track)
		}
	}
}

func TestProvider_Options(t *testing.T) {
	// Test that options are properly applied
	customInterval := 15 * time.Second
	customSize := 250
	
	provider, err := New("/test",
		WithFlushInterval(customInterval),
		WithFlushSize(customSize),
	)
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	
	if provider.flushInterval != customInterval {
		t.Errorf("FlushInterval = %v, want %v", provider.flushInterval, customInterval)
	}
	
	if provider.flushSize != customSize {
		t.Errorf("FlushSize = %d, want %d", provider.flushSize, customSize)
	}
}