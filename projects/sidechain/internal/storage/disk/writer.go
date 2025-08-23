package disk

import (
	"context"
	"fmt"
	"sync"
	
	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

// Writer implements storage.WriteCloser for a specific track
// Coordinates JSONLWriter and StateManager
type Writer struct {
	trackID string
	jsonl   *JSONLWriter
	state   *StateManager
	mu      sync.Mutex
}

// Write implements storage.Writer.Write
func (w *Writer) Write(ctx context.Context, event indexer.Event) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	
	// Check if epoch changed
	epochChanged, err := w.state.SetEpochIfNeeded(event.Epoch)
	if err != nil {
		return fmt.Errorf("failed to update epoch: %w", err)
	}
	
	// If epoch changed, update JSONL writer
	if epochChanged {
		if err := w.jsonl.SetEpoch(event.Epoch); err != nil {
			return fmt.Errorf("failed to set jsonl epoch: %w", err)
		}
	}
	
	// Write the event
	if err := w.jsonl.WriteEvent(event); err != nil {
		return fmt.Errorf("failed to write event: %w", err)
	}
	
	// Update state
	w.state.IncrementEventsRecorded()
	if err := w.state.UpdatePosition(event.Height, event.TxIndex); err != nil {
		return fmt.Errorf("failed to update state: %w", err)
	}
	
	return nil
}

// Close closes the writer and saves state
func (w *Writer) Close() error {
	w.mu.Lock()
	defer w.mu.Unlock()
	
	// Collect errors but try to close everything
	var errs []error
	
	// Save final state
	if err := w.state.Save(); err != nil {
		errs = append(errs, fmt.Errorf("state save: %w", err))
	}
	
	// Close JSONL writer
	if err := w.jsonl.Close(); err != nil {
		errs = append(errs, fmt.Errorf("jsonl close: %w", err))
	}
	
	// Return combined error if any
	if len(errs) > 0 {
		return fmt.Errorf("close errors: %v", errs)
	}
	
	return nil
}