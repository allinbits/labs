package disk

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
	
	"github.com/spf13/afero"
	
	"github.com/allinbits/labs/projects/sidechain/internal/indexer"
)

// JSONLWriter handles writing events to JSONL files with rotation
// No mutex needed - Writer handles synchronization
// No event manipulation - validates instead
type JSONLWriter struct {
	fs            afero.Fs
	basePath      string
	trackID       string
	flushInterval time.Duration
	flushSize     int
	
	// Lazily initialized on first write
	file         afero.File
	writer       *bufio.Writer
	currentHour  string
	currentEpoch int64
	lastFlush    time.Time
	eventCount   int64
}

// NewJSONLWriter creates a new JSONL writer for a track
// Deprecated: Use Provider.NewTrackWriter instead
func NewJSONLWriter(basePath, trackID string, epoch int64) *JSONLWriter {
	return &JSONLWriter{
		fs:            afero.NewOsFs(),
		basePath:      basePath,
		trackID:       trackID,
		flushInterval: 5 * time.Second,
		flushSize:     100,
	}
}

// WriteEvent writes an event to the JSONL file
// Validates but doesn't modify the event
func (w *JSONLWriter) WriteEvent(event indexer.Event) error {
	// Validate event
	if err := w.validateEvent(event); err != nil {
		return fmt.Errorf("invalid event: %w", err)
	}
	
	// Ensure file is open for current hour and epoch
	if err := w.ensureFile(event.Epoch); err != nil {
		return fmt.Errorf("failed to ensure file: %w", err)
	}
	
	// Marshal event to JSON
	data, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}
	
	// Write JSON line
	if _, err := w.writer.Write(data); err != nil {
		return fmt.Errorf("failed to write event: %w", err)
	}
	if err := w.writer.WriteByte('\n'); err != nil {
		return fmt.Errorf("failed to write newline: %w", err)
	}
	
	w.eventCount++
	
	// Auto-flush based on count or time
	if w.shouldFlush() {
		if err := w.flush(); err != nil {
			return fmt.Errorf("failed to flush: %w", err)
		}
	}
	
	return nil
}

// SetEpoch updates the epoch for the writer
// This will cause file rotation on next write
func (w *JSONLWriter) SetEpoch(epoch int64) error {
	if w.currentEpoch != epoch {
		// Close current file if open
		if err := w.closeFile(); err != nil {
			return err
		}
		w.currentEpoch = epoch
	}
	return nil
}

// Flush writes buffered data to disk
func (w *JSONLWriter) Flush() error {
	return w.flush()
}

// Close flushes and closes the writer
func (w *JSONLWriter) Close() error {
	return w.closeFile()
}

// validateEvent checks that the event has required fields
func (w *JSONLWriter) validateEvent(event indexer.Event) error {
	if event.Epoch == 0 {
		return fmt.Errorf("event missing epoch")
	}
	if event.Height == 0 {
		return fmt.Errorf("event missing height")
	}
	if event.EventType == "" {
		return fmt.Errorf("event missing type")
	}
	if event.PkgPath == "" {
		return fmt.Errorf("event missing package path")
	}
	// Timestamp is optional - indexer should set it
	return nil
}

// ensureFile makes sure we have an open file for the current hour and epoch
func (w *JSONLWriter) ensureFile(epoch int64) error {
	currentHour := time.Now().Format("2006-01-02-15")
	
	// Check if we need to rotate (hour changed or epoch changed)
	needRotation := w.file == nil || 
		w.currentHour != currentHour || 
		w.currentEpoch != epoch
	
	if needRotation {
		// Close current file if open
		if err := w.closeFile(); err != nil {
			return err
		}
		
		// Update epoch
		w.currentEpoch = epoch
		
		// Open new file
		if err := w.openFile(currentHour); err != nil {
			return err
		}
	}
	
	return nil
}

// openFile creates a new file for the current hour
func (w *JSONLWriter) openFile(hour string) error {
	// Create directory path: {basePath}/{track_id}/{epoch}/
	dirPath := filepath.Join(w.basePath, w.trackID, fmt.Sprintf("%d", w.currentEpoch))
	if err := w.fs.MkdirAll(dirPath, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}
	
	// Create file path: {hour}.jsonl
	filePath := filepath.Join(dirPath, fmt.Sprintf("%s.jsonl", hour))
	
	// Open file for append (creates if not exists)
	file, err := w.fs.OpenFile(filePath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	
	w.file = file
	w.writer = bufio.NewWriterSize(file, 64*1024) // 64KB buffer
	w.currentHour = hour
	w.lastFlush = time.Now()
	w.eventCount = 0
	
	return nil
}

// closeFile closes the current file
func (w *JSONLWriter) closeFile() error {
	if w.writer != nil {
		if err := w.writer.Flush(); err != nil {
			return fmt.Errorf("failed to flush writer: %w", err)
		}
		w.writer = nil
	}
	
	if w.file != nil {
		if err := w.file.Close(); err != nil {
			return fmt.Errorf("failed to close file: %w", err)
		}
		w.file = nil
	}
	
	w.currentHour = ""
	
	return nil
}

// flush performs the actual flush
func (w *JSONLWriter) flush() error {
	if w.writer != nil {
		if err := w.writer.Flush(); err != nil {
			return fmt.Errorf("failed to flush writer: %w", err)
		}
		w.lastFlush = time.Now()
	}
	return nil
}

// shouldFlush determines if we should flush based on count or time
func (w *JSONLWriter) shouldFlush() bool {
	return w.eventCount >= int64(w.flushSize) || 
		time.Since(w.lastFlush) > w.flushInterval
}

// GetCurrentPath returns the current file path (for debugging)
func (w *JSONLWriter) GetCurrentPath() string {
	if w.currentHour == "" {
		return ""
	}
	
	return filepath.Join(
		w.basePath,
		w.trackID,
		fmt.Sprintf("%d", w.currentEpoch),
		fmt.Sprintf("%s.jsonl", w.currentHour),
	)
}