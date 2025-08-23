package config

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/BurntSushi/toml"
)

// GlobalConfig represents the main sidechain configuration
type GlobalConfig struct {
	GraphQLURL        string               `toml:"graphql_url"`
	DuplicateStrategy string               `toml:"duplicate_strategy"` // error | override | skip
	Storage           StorageConfig        `toml:"storage"`
	Observability     *ObservabilityConfig `toml:"observability,omitempty"`
}

// StorageConfig represents the storage configuration
type StorageConfig struct {
	Type string      `toml:"type"` // "disk", "s3", etc.
	
	// Storage-specific configs (only one will be populated based on Type)
	Disk *DiskConfig `toml:"disk,omitempty"`
	S3   *S3Config   `toml:"s3,omitempty"`
}

// DiskConfig for local filesystem storage
type DiskConfig struct {
	Path string `toml:"path"`
}

// S3Config for S3-compatible object storage
// AWS credentials are NEVER stored here - use environment variables or IAM roles:
// - AWS_ACCESS_KEY_ID
// - AWS_SECRET_ACCESS_KEY
// - AWS_REGION (can override config)
// - AWS_S3_BUCKET (can override config)
type S3Config struct {
	Bucket        string `toml:"bucket,omitempty"`        // Can be overridden by AWS_S3_BUCKET env var
	Region        string `toml:"region,omitempty"`        // Can be overridden by AWS_REGION env var
	Endpoint      string `toml:"endpoint,omitempty"`      // For MinIO, S3-compatible services
	Prefix        string `toml:"prefix,omitempty"`        // Optional path prefix
	BufferTimeout string `toml:"buffer_timeout,omitempty"` // e.g. "30s"
}

// ObservabilityConfig represents observability configuration (optional)
type ObservabilityConfig struct {
	MetricsEnabled  bool   `toml:"metrics_enabled,omitempty"`
	MetricsEndpoint string `toml:"metrics_endpoint,omitempty"`
	ServiceName     string `toml:"service_name,omitempty"`
}

// TrackConfig represents a single track configuration
type TrackConfig struct {
	Track           string   `toml:"track"`            // Unique identifier
	Description     string   `toml:"description"`
	Packages        []string `toml:"packages"`
	EventFilter     []string `toml:"event_filter"`     // Empty means all events
	IntervalSeconds int      `toml:"interval_seconds"`
}

// Config represents the complete configuration
type Config struct {
	Global GlobalConfig
	Tracks map[string]*TrackConfig // Key is track ID
}

// LoadGlobalConfig loads the global configuration from a TOML file
func LoadGlobalConfig(path string) (*GlobalConfig, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open config file: %w", err)
	}
	defer file.Close()

	var config GlobalConfig
	decoder := toml.NewDecoder(file)
	if _, err := decoder.Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode config: %w", err)
	}

	// Set defaults
	if config.DuplicateStrategy == "" {
		config.DuplicateStrategy = "error"
	}
	
	// Default to disk storage if not specified
	if config.Storage.Type == "" {
		config.Storage.Type = "disk"
		config.Storage.Disk = &DiskConfig{
			Path: "./events",
		}
	}
	
	// Apply environment variable overrides for S3
	if config.Storage.Type == "s3" && config.Storage.S3 != nil {
		applyS3EnvOverrides(config.Storage.S3)
	}

	return &config, nil
}

// applyS3EnvOverrides applies AWS environment variable overrides to S3 config
func applyS3EnvOverrides(s3cfg *S3Config) {
	// AWS SDK standard environment variables
	if bucket := os.Getenv("AWS_S3_BUCKET"); bucket != "" {
		s3cfg.Bucket = bucket
	}
	if region := os.Getenv("AWS_REGION"); region != "" {
		s3cfg.Region = region
	} else if region := os.Getenv("AWS_DEFAULT_REGION"); region != "" {
		s3cfg.Region = region
	}
	
	// Custom endpoint for S3-compatible services
	if endpoint := os.Getenv("AWS_S3_ENDPOINT"); endpoint != "" {
		s3cfg.Endpoint = endpoint
	}
}

// LoadTrackConfigs loads all track configurations from a directory
func LoadTrackConfigs(dir string, duplicateStrategy string) (map[string]*TrackConfig, error) {
	tracks := make(map[string]*TrackConfig)

	// Find all .toml files in the directory
	pattern := filepath.Join(dir, "*.toml")
	files, err := filepath.Glob(pattern)
	if err != nil {
		return nil, fmt.Errorf("failed to glob track files: %w", err)
	}

	// Also check for subdirectories
	subPattern := filepath.Join(dir, "*", "*.toml")
	subFiles, err := filepath.Glob(subPattern)
	if err != nil {
		return nil, fmt.Errorf("failed to glob track files in subdirectories: %w", err)
	}
	files = append(files, subFiles...)

	// Sort files for deterministic loading order
	sort.Strings(files)

	for _, file := range files {
		track, err := loadTrackConfig(file)
		if err != nil {
			return nil, fmt.Errorf("failed to load track %s: %w", file, err)
		}

		// Handle duplicates based on strategy
		if _, exists := tracks[track.Track]; exists {
			switch duplicateStrategy {
			case "error":
				return nil, fmt.Errorf("duplicate track ID '%s' found in %s", track.Track, file)
			case "override":
				fmt.Printf("WARNING: Overriding track '%s' with config from %s\n", track.Track, file)
				tracks[track.Track] = track
			case "skip":
				fmt.Printf("WARNING: Skipping duplicate track '%s' from %s\n", track.Track, file)
				// Keep the existing one
			default:
				return nil, fmt.Errorf("unknown duplicate strategy: %s", duplicateStrategy)
			}
		} else {
			tracks[track.Track] = track
		}
	}

	return tracks, nil
}

// loadTrackConfig loads a single track configuration file
func loadTrackConfig(path string) (*TrackConfig, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open track file: %w", err)
	}
	defer file.Close()

	var track TrackConfig
	decoder := toml.NewDecoder(file)
	if _, err := decoder.Decode(&track); err != nil {
		return nil, fmt.Errorf("failed to decode track config: %w", err)
	}

	// If track ID is not specified, use filename (without extension)
	if track.Track == "" {
		base := filepath.Base(path)
		track.Track = strings.TrimSuffix(base, filepath.Ext(base))
		fmt.Printf("INFO: Using filename '%s' as track identifier\n", track.Track)
	}

	// Validate required fields
	if len(track.Packages) == 0 {
		return nil, fmt.Errorf("track must specify at least one package")
	}
	if track.IntervalSeconds <= 0 {
		track.IntervalSeconds = 10 // Default to 10 seconds
	}

	return &track, nil
}

// LoadConfig loads the complete configuration
func LoadConfig(globalPath string, tracksDir string) (*Config, error) {
	global, err := LoadGlobalConfig(globalPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load global config: %w", err)
	}

	tracks, err := LoadTrackConfigs(tracksDir, global.DuplicateStrategy)
	if err != nil {
		return nil, fmt.Errorf("failed to load track configs: %w", err)
	}

	if len(tracks) == 0 {
		return nil, fmt.Errorf("no track configurations found in %s", tracksDir)
	}

	return &Config{
		Global: *global,
		Tracks: tracks,
	}, nil
}

// ValidateConfig validates the configuration without running
func ValidateConfig(w io.Writer, globalPath string, tracksDir string) error {
	config, err := LoadConfig(globalPath, tracksDir)
	if err != nil {
		return err
	}

	fmt.Fprintf(w, "Configuration is valid!\n")
	fmt.Fprintf(w, "GraphQL URL: %s\n", config.Global.GraphQLURL)
	fmt.Fprintf(w, "Duplicate Strategy: %s\n", config.Global.DuplicateStrategy)
	
	// Display storage configuration
	fmt.Fprintf(w, "Storage Type: %s\n", config.Global.Storage.Type)
	switch config.Global.Storage.Type {
	case "disk":
		if config.Global.Storage.Disk != nil {
			fmt.Fprintf(w, "  Path: %s\n", config.Global.Storage.Disk.Path)
		}
	case "s3":
		if config.Global.Storage.S3 != nil {
			fmt.Fprintf(w, "  Bucket: %s\n", config.Global.Storage.S3.Bucket)
			fmt.Fprintf(w, "  Region: %s\n", config.Global.Storage.S3.Region)
			if config.Global.Storage.S3.Prefix != "" {
				fmt.Fprintf(w, "  Prefix: %s\n", config.Global.Storage.S3.Prefix)
			}
		}
	}

	fmt.Fprintf(w, "\nTracks (%d):\n", len(config.Tracks))
	
	// Sort tracks for consistent output
	var trackIDs []string
	for id := range config.Tracks {
		trackIDs = append(trackIDs, id)
	}
	sort.Strings(trackIDs)
	
	for _, id := range trackIDs {
		track := config.Tracks[id]
		fmt.Fprintf(w, "  - %s: %s\n", id, track.Description)
		fmt.Fprintf(w, "    Packages: %v\n", track.Packages)
		if len(track.EventFilter) > 0 {
			fmt.Fprintf(w, "    Events: %v\n", track.EventFilter)
		}
		fmt.Fprintf(w, "    Interval: %ds\n", track.IntervalSeconds)
	}

	return nil
}