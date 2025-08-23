package track

import (
	"context"
	"fmt"
	"log/slog"
	"time"
	
	"github.com/allinbits/labs/projects/sidechain/internal/config"
	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
	"github.com/allinbits/labs/projects/sidechain/internal/storage"
)

// State represents the current state of a track
type State struct {
	TrackID             string `json:"track_id"`
	Epoch               int64  `json:"epoch"`
	LastProcessedHeight int64  `json:"last_processed_height"`
	LastProcessedTx     int64  `json:"last_processed_tx"`
	EventsRecorded      int64  `json:"events_recorded"`
	LastUpdate          int64  `json:"last_update"`
}

// Worker processes events for a single track
type Worker struct {
	config   *config.TrackConfig
	storage  storage.WriteCloser
	indexer  *indexer.Client
	logger   *slog.Logger
	
	// Current state
	state State
	
	// Control
	stopCh chan struct{}
}

// NewWorker creates a new track worker
func NewWorker(cfg *config.TrackConfig, storage storage.WriteCloser, indexer *indexer.Client, logger *slog.Logger) *Worker {
	return &Worker{
		config:  cfg,
		storage: storage,
		indexer: indexer,
		logger:  logger.With("track", cfg.Track),
		state: State{
			TrackID: cfg.Track,
		},
		stopCh: make(chan struct{}),
	}
}

// Run starts the worker's event processing loop
func (w *Worker) Run(ctx context.Context) error {
	w.logger.Info("Starting track worker",
		"packages", w.config.Packages,
		"events", w.config.EventFilter)
	
	ticker := time.NewTicker(5 * time.Second) // Poll interval
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			w.logger.Info("Track worker stopping (context cancelled)")
			return ctx.Err()
			
		case <-w.stopCh:
			w.logger.Info("Track worker stopping (stop signal)")
			return nil
			
		case <-ticker.C:
			if err := w.poll(ctx); err != nil {
				w.logger.Error("Failed to poll for events",
					"error", err,
					"last_height", w.state.LastProcessedHeight,
					"last_tx", w.state.LastProcessedTx)
				// Continue polling despite errors
			}
		}
	}
}

// poll queries for new events and processes them
func (w *Worker) poll(ctx context.Context) error {
	// Query for block info to get latest height
	blockInfo, err := w.indexer.QueryBlockInfo(ctx)
	if err != nil {
		return fmt.Errorf("failed to query block info: %w", err)
	}
	
	// Check for epoch change
	if w.state.Epoch != 0 && w.state.Epoch != blockInfo.Genesis.Timestamp {
		w.logger.Warn("Epoch change detected",
			"old_epoch", w.state.Epoch,
			"new_epoch", blockInfo.Genesis.Timestamp)
		// Reset state for new epoch
		w.state.Epoch = blockInfo.Genesis.Timestamp
		w.state.LastProcessedHeight = 0
		w.state.LastProcessedTx = 0
	} else if w.state.Epoch == 0 {
		// First run, set epoch
		w.state.Epoch = blockInfo.Genesis.Timestamp
		w.logger.Info("Initial epoch set",
			"epoch", w.state.Epoch)
	}
	
	// No new blocks to process
	if w.state.LastProcessedHeight >= blockInfo.LatestHeight {
		return nil
	}
	
	// Query for events
	transactions, err := w.indexer.QueryEvents(
		ctx,
		w.config.Packages,
		w.config.EventFilter,
		w.state.LastProcessedHeight,
		w.state.LastProcessedTx,
		blockInfo.LatestHeight,
	)
	if err != nil {
		return fmt.Errorf("failed to query events: %w", err)
	}
	
	// Process events
	eventCount := 0
	for _, tx := range transactions {
		for _, gnoEvent := range tx.Response.Events {
			// Convert to indexer.Event
			event := indexer.Event{
				Epoch:     w.state.Epoch,
				Timestamp: time.Now().Unix(), // TODO: Get from block
				Height:    tx.BlockHeight,
				TxIndex:   tx.Index,
				EventType: gnoEvent.Type,
				PkgPath:   gnoEvent.PkgPath,
				Attrs:     gnoEvent.Attrs,
			}
			
			// Write event to storage
			if err := w.storage.Write(ctx, event); err != nil {
				return fmt.Errorf("failed to write event: %w", err)
			}
			
			eventCount++
		}
		
		// Update state after processing transaction
		w.state.LastProcessedHeight = tx.BlockHeight
		w.state.LastProcessedTx = tx.Index
	}
	
	if eventCount > 0 {
		w.state.EventsRecorded += int64(eventCount)
		w.state.LastUpdate = time.Now().Unix()
		
		w.logger.Info("Processed events",
			"count", eventCount,
			"height", w.state.LastProcessedHeight,
			"total_recorded", w.state.EventsRecorded)
	}
	
	return nil
}

// Stop signals the worker to stop
func (w *Worker) Stop() {
	close(w.stopCh)
}

// GetState returns the current state
func (w *Worker) GetState() State {
	return w.state
}

// Close closes the storage writer
func (w *Worker) Close() error {
	return w.storage.Close()
}