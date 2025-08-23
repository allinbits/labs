package s3

import (
	"context"
	"fmt"
	"sync"
	
	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

// Writer implements storage.WriteCloser for a specific track using S3
type Writer struct {
	trackID  string
	buffered *BufferedWriter
	state    *StateManager
	mu       sync.Mutex
}

// Write implements storage.Writer.Write
func (w *Writer) Write(ctx context.Context, event indexer.Event) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	
	// Check if epoch changed
	epochChanged, err := w.state.SetEpochIfNeeded(ctx, event.Epoch)
	if err != nil {
		return fmt.Errorf("failed to update epoch: %w", err)
	}
	
	// If epoch changed, flush current buffer and start new epoch
	if epochChanged {
		if err := w.buffered.Flush(ctx); err != nil {
			return fmt.Errorf("failed to flush on epoch change: %w", err)
		}
		w.buffered.SetEpoch(event.Epoch)
	}
	
	// Write the event to buffer
	if err := w.buffered.WriteEvent(ctx, event); err != nil {
		return fmt.Errorf("failed to write event: %w", err)
	}
	
	// Update state
	w.state.IncrementEventsRecorded()
	if err := w.state.UpdatePosition(ctx, event.Height, event.TxIndex); err != nil {
		return fmt.Errorf("failed to update state: %w", err)
	}
	
	return nil
}

// Close flushes any buffered events and closes the writer
func (w *Writer) Close() error {
	w.mu.Lock()
	defer w.mu.Unlock()
	
	ctx := context.Background()
	
	// Collect errors but try to close everything
	var errs []error
	
	// Flush any remaining buffered events
	if err := w.buffered.Close(ctx); err != nil {
		errs = append(errs, fmt.Errorf("buffer close: %w", err))
	}
	
	// Save final state
	if err := w.state.Save(ctx); err != nil {
		errs = append(errs, fmt.Errorf("state save: %w", err))
	}
	
	// Return combined error if any
	if len(errs) > 0 {
		return fmt.Errorf("close errors: %v", errs)
	}
	
	return nil
}