package indexer

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"
)


// BlockInfoQuerier is an interface for querying block information
type BlockInfoQuerier interface {
	QueryBlockInfo(ctx context.Context) (*BlockInfo, error)
}

// EpochDetector monitors for chain resets by checking genesis block
type EpochDetector struct {
	querier       BlockInfoQuerier
	logger        *slog.Logger
	checkInterval time.Duration
	
	mu           sync.RWMutex
	currentEpoch int64
	listeners    []func(oldEpoch, newEpoch int64)
}

// NewEpochDetector creates a new epoch detector
func NewEpochDetector(querier BlockInfoQuerier, logger *slog.Logger) *EpochDetector {
	return &EpochDetector{
		querier:       querier,
		logger:        logger,
		checkInterval: 30 * time.Second, // Check every 30 seconds
		listeners:     make([]func(oldEpoch, newEpoch int64), 0),
	}
}

// Start begins monitoring for epoch changes
func (ed *EpochDetector) Start(ctx context.Context) error {
	// Get initial block info
	blockInfo, err := ed.querier.QueryBlockInfo(ctx)
	if err != nil {
		return fmt.Errorf("failed to get initial block info: %w", err)
	}
	
	ed.mu.Lock()
	ed.currentEpoch = blockInfo.Genesis.Timestamp
	ed.mu.Unlock()
	
	ed.logger.Info("Epoch detector started",
		"epoch", ed.currentEpoch,
		"genesis_hash", blockInfo.Genesis.Hash,
		"latest_height", blockInfo.LatestHeight)
	
	// Start monitoring loop
	go ed.monitor(ctx)
	
	return nil
}

// monitor runs the monitoring loop
func (ed *EpochDetector) monitor(ctx context.Context) {
	ticker := time.NewTicker(ed.checkInterval)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			ed.logger.Info("Epoch detector stopped")
			return
			
		case <-ticker.C:
			if err := ed.check(ctx); err != nil {
				ed.logger.Error("Failed to check epoch",
					"error", err)
			}
		}
	}
}

// check queries for the current epoch and detects changes
func (ed *EpochDetector) check(ctx context.Context) error {
	blockInfo, err := ed.querier.QueryBlockInfo(ctx)
	if err != nil {
		return fmt.Errorf("failed to query block info: %w", err)
	}
	
	ed.mu.RLock()
	oldEpoch := ed.currentEpoch
	ed.mu.RUnlock()
	
	if blockInfo.Genesis.Timestamp != oldEpoch {
		ed.logger.Warn("EPOCH CHANGE DETECTED",
			"old_epoch", oldEpoch,
			"new_epoch", blockInfo.Genesis.Timestamp,
			"genesis_hash", blockInfo.Genesis.Hash,
			"latest_height", blockInfo.LatestHeight)
		
		// Update epoch
		ed.mu.Lock()
		ed.currentEpoch = blockInfo.Genesis.Timestamp
		listeners := make([]func(oldEpoch, newEpoch int64), len(ed.listeners))
		copy(listeners, ed.listeners)
		ed.mu.Unlock()
		
		// Notify all listeners
		for _, listener := range listeners {
			go listener(oldEpoch, blockInfo.Genesis.Timestamp)
		}
	}
	
	return nil
}

// GetCurrentEpoch returns the current epoch
func (ed *EpochDetector) GetCurrentEpoch() int64 {
	ed.mu.RLock()
	defer ed.mu.RUnlock()
	return ed.currentEpoch
}

// OnEpochChange registers a callback for epoch changes
func (ed *EpochDetector) OnEpochChange(callback func(oldEpoch, newEpoch int64)) {
	ed.mu.Lock()
	defer ed.mu.Unlock()
	ed.listeners = append(ed.listeners, callback)
}

// SetCheckInterval updates the check interval (mainly for testing)
func (ed *EpochDetector) SetCheckInterval(interval time.Duration) {
	ed.checkInterval = interval
}