package disk

import (
	"fmt"
	"time"
	
	"github.com/spf13/afero"
)

// Provider implements storage.Provider using local filesystem
// It's a simple factory - no state tracking or caching
type Provider struct {
	fs            afero.Fs
	basePath      string
	flushInterval time.Duration
	flushSize     int
}

// Option configures a Provider
type Option func(*Provider)

// WithFS sets a custom filesystem (useful for testing)
func WithFS(fs afero.Fs) Option {
	return func(p *Provider) {
		p.fs = fs
	}
}

// WithFlushInterval sets a custom flush interval (default: 5s)
// Mainly for testing - production should use defaults
func WithFlushInterval(d time.Duration) Option {
	return func(p *Provider) {
		p.flushInterval = d
	}
}

// WithFlushSize sets a custom flush size (default: 100 events)
// Mainly for testing - production should use defaults
func WithFlushSize(size int) Option {
	return func(p *Provider) {
		p.flushSize = size
	}
}

// New creates a new disk storage provider
func New(path string, opts ...Option) (*Provider, error) {
	if path == "" {
		return nil, fmt.Errorf("disk storage requires a path")
	}
	
	// Start with defaults
	p := &Provider{
		fs:            afero.NewOsFs(),
		basePath:      path,
		flushInterval: 5 * time.Second,
		flushSize:     100,
	}
	
	// Apply options
	for _, opt := range opts {
		opt(p)
	}
	
	return p, nil
}

// NewTrackWriter creates a new track-specific writer
func (p *Provider) NewTrackWriter(trackID string) (*Writer, error) {
	// Create state manager
	stateManager := &StateManager{
		fs:       p.fs,
		basePath: p.basePath,
		trackID:  trackID,
		state: TrackState{
			TrackID: trackID,
			Epoch:   0, // Will be set from first event
		},
	}
	
	// Load existing state or initialize new
	if err := stateManager.Load(); err != nil {
		return nil, err
	}
	
	// Create JSONL writer with provider's options
	jsonlWriter := &JSONLWriter{
		fs:            p.fs,
		trackID:       trackID,
		basePath:      p.basePath,
		flushInterval: p.flushInterval,
		flushSize:     p.flushSize,
	}
	
	// Create and return writer
	return &Writer{
		trackID: trackID,
		jsonl:   jsonlWriter,
		state:   stateManager,
	}, nil
}

// Close implements storage.Provider.Close
// Nothing to close since we don't track writers
func (p *Provider) Close() error {
	return nil
}