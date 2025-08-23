package mock

import (
	"context"
	"sync"

	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
	"github.com/allinbits/labs/projects/sidechain/internal/storage"
)

// Provider is a mock implementation of storage.Provider for testing
type Provider struct {
	mu       sync.Mutex
	writers  map[string]*Writer
	closed   bool
	
	// Hooks for testing
	OnNewTrackWriter func(trackID string) error
	OnClose          func() error
}

// NewProvider creates a new mock provider
func NewProvider() *Provider {
	return &Provider{
		writers: make(map[string]*Writer),
	}
}

// NewTrackWriter creates a new mock writer for a track
func (p *Provider) NewTrackWriter(trackID string) (storage.WriteCloser, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.closed {
		return nil, storage.ErrClosed
	}

	if p.OnNewTrackWriter != nil {
		if err := p.OnNewTrackWriter(trackID); err != nil {
			return nil, err
		}
	}

	writer := &Writer{
		trackID: trackID,
		events:  make([]indexer.Event, 0),
	}
	p.writers[trackID] = writer
	return writer, nil
}

// Close closes the provider
func (p *Provider) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.closed {
		return nil
	}

	if p.OnClose != nil {
		if err := p.OnClose(); err != nil {
			return err
		}
	}

	// Close all writers
	for _, w := range p.writers {
		w.Close()
	}

	p.closed = true
	return nil
}

// GetWriter returns a writer for testing assertions
func (p *Provider) GetWriter(trackID string) *Writer {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.writers[trackID]
}

// Writer is a mock implementation of storage.WriteCloser
type Writer struct {
	mu      sync.Mutex
	trackID string
	events  []indexer.Event
	closed  bool

	// Hooks for testing
	OnWrite func(event indexer.Event) error
	OnClose func() error
}

// Write writes an event to the mock storage
func (w *Writer) Write(ctx context.Context, event indexer.Event) error {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.closed {
		return storage.ErrClosed
	}

	if w.OnWrite != nil {
		if err := w.OnWrite(event); err != nil {
			return err
		}
	}

	w.events = append(w.events, event)
	return nil
}

// Close closes the writer
func (w *Writer) Close() error {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.closed {
		return nil
	}

	if w.OnClose != nil {
		if err := w.OnClose(); err != nil {
			return err
		}
	}

	w.closed = true
	return nil
}

// GetEvents returns all events written (for testing)
func (w *Writer) GetEvents() []indexer.Event {
	w.mu.Lock()
	defer w.mu.Unlock()
	
	// Return a copy to avoid race conditions
	events := make([]indexer.Event, len(w.events))
	copy(events, w.events)
	return events
}

// GetEventCount returns the number of events written
func (w *Writer) GetEventCount() int {
	w.mu.Lock()
	defer w.mu.Unlock()
	return len(w.events)
}