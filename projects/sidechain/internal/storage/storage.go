package storage

import (
	"context"

	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

// Provider is an interface for creating track-specific writers
// and closers. A Provider is meant to encapsulate the logic for
// managing the lifecycle of these resources such as disk and blob
// storage but could be extended to support other storage backends.
type Provider interface {
	// Closer is an interface for closing the Provider
	Closer
	// NewTrackWriter creates a new event writer and closer for the specified track
	NewTrackWriter(trackID string) (WriteCloser, error)
}

// Writer writes events to storage for a specific track
type Writer interface {
	// Write writes take a context and an event to write to a storage provider and
	// returns an error if the write fails.
	Write(ctx context.Context, event indexer.Event) error
}

// Closer is an interface for closing resources
type Closer interface {
	Close() error
}

// WriteCloser is an interface for writing and closing resources
type WriteCloser interface {
	Writer
	Closer
}
