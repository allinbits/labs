package storage

import (
	"errors"
	"strconv"
	"time"
)

// Common storage errors
var (
	ErrConcurrencyConflict = errors.New("concurrent modification detected")
	ErrGuildConfigNotFound = errors.New("guild config not found")
)

// GuildQueryState tracks per-guild progress for each query
type GuildQueryState struct {
	GuildID              string            `json:"guild_id"`
	QueryID              string            `json:"query_id"`
	LastProcessedBlock   int64             `json:"last_processed_block"`
	LastProcessedTxIndex int64             `json:"last_processed_tx_index"` // Transaction index within block
	IsExecuting          bool              `json:"is_executing"`            // Prevents concurrent execution
	LastRunTimestamp     time.Time         `json:"last_run_timestamp"`
	NextRunTimestamp     time.Time         `json:"next_run_timestamp"`
	Enabled              bool              `json:"enabled"`
	State                map[string]any    `json:"state,omitempty"` // Query-specific state
	ErrorCount           int               `json:"error_count"`
	LastError            string            `json:"last_error,omitempty"`
	LastErrorTime        time.Time         `json:"last_error_time,omitempty"`
}

// GuildConfig represents the configuration for a Discord guild
type GuildConfig struct {
	GuildID        string                        `json:"guild_id"`
	AdminRoleID    string                        `json:"admin_role_id,omitempty"`
	VerifiedRoleID string                        `json:"verified_role_id,omitempty"`
	Settings       map[string]string             `json:"settings,omitempty"`
	QueryStates    map[string]*GuildQueryState   `json:"query_states,omitempty"`
	LastUpdated    time.Time                     `json:"last_updated"`
	
	// ETag is used for optimistic concurrency control
	// Not serialized to JSON - managed by storage layer
	ETag string `json:"-"`
}

// GlobalConfig represents global bot state
type GlobalConfig struct {
	ConfigID                 string    `json:"config_id"`
	LastProcessedBlockHeight int64     `json:"last_processed_block_height"`
	LastUpdated              time.Time `json:"last_updated"`
	
	// ETag is used for optimistic concurrency control
	ETag string `json:"-"`
}

// ConfigStore defines the interface for guild configuration storage
type ConfigStore interface {
	Get(guildID string) (*GuildConfig, error)
	Set(guildID string, config *GuildConfig) error
	Delete(guildID string) error
	
	// Global config methods
	GetGlobal() (*GlobalConfig, error)
	SetGlobal(config *GlobalConfig) error
}

// NewGuildConfig creates a new guild configuration with default values
func NewGuildConfig(guildID string) *GuildConfig {
	return &GuildConfig{
		GuildID:     guildID,
		Settings:    make(map[string]string),
		QueryStates: make(map[string]*GuildQueryState),
		LastUpdated: time.Now(),
	}
}

// NewGuildQueryState creates a new guild query state
func NewGuildQueryState(guildID, queryID string, enabled bool) *GuildQueryState {
	now := time.Now()
	return &GuildQueryState{
		GuildID:            guildID,
		QueryID:            queryID,
		LastProcessedBlock: 0,
		LastRunTimestamp:   time.Time{},
		NextRunTimestamp:   now,
		Enabled:            enabled,
		State:              make(map[string]any),
		ErrorCount:         0,
	}
}

// Type-safe settings helpers

// GetString retrieves a string setting with a default value
func (c *GuildConfig) GetString(key, defaultValue string) string {
	if val, exists := c.Settings[key]; exists {
		return val
	}
	return defaultValue
}

// SetString sets a string setting
func (c *GuildConfig) SetString(key, value string) {
	if c.Settings == nil {
		c.Settings = make(map[string]string)
	}
	c.Settings[key] = value
	c.LastUpdated = time.Now()
}

// GetBool retrieves a boolean setting with a default value
func (c *GuildConfig) GetBool(key string, defaultValue bool) bool {
	if val, exists := c.Settings[key]; exists {
		if parsed, err := strconv.ParseBool(val); err == nil {
			return parsed
		}
	}
	return defaultValue
}

// SetBool sets a boolean setting
func (c *GuildConfig) SetBool(key string, value bool) {
	c.SetString(key, strconv.FormatBool(value))
}

// GetInt retrieves an integer setting with a default value
func (c *GuildConfig) GetInt(key string, defaultValue int) int {
	if val, exists := c.Settings[key]; exists {
		if parsed, err := strconv.Atoi(val); err == nil {
			return parsed
		}
	}
	return defaultValue
}

// SetInt sets an integer setting
func (c *GuildConfig) SetInt(key string, value int) {
	c.SetString(key, strconv.Itoa(value))
}

// GetDuration retrieves a duration setting with a default value
func (c *GuildConfig) GetDuration(key string, defaultValue time.Duration) time.Duration {
	if val, exists := c.Settings[key]; exists {
		if parsed, err := time.ParseDuration(val); err == nil {
			return parsed
		}
	}
	return defaultValue
}

// SetDuration sets a duration setting
func (c *GuildConfig) SetDuration(key string, value time.Duration) {
	c.SetString(key, value.String())
}

// HasAdminRole returns true if an admin role is configured
func (c *GuildConfig) HasAdminRole() bool {
	return c.AdminRoleID != ""
}

// HasVerifiedRole returns true if a verified role is configured
func (c *GuildConfig) HasVerifiedRole() bool {
	return c.VerifiedRoleID != ""
}

// Query state management methods

// GetQueryState retrieves a query state by ID
func (c *GuildConfig) GetQueryState(queryID string) (*GuildQueryState, bool) {
	if c.QueryStates == nil {
		return nil, false
	}
	state, exists := c.QueryStates[queryID]
	return state, exists
}

// SetQueryState sets a query state
func (c *GuildConfig) SetQueryState(queryID string, state *GuildQueryState) {
	if c.QueryStates == nil {
		c.QueryStates = make(map[string]*GuildQueryState)
	}
	c.QueryStates[queryID] = state
	c.LastUpdated = time.Now()
}

// EnsureQueryState ensures a query state exists, creating it if needed
func (c *GuildConfig) EnsureQueryState(queryID string, enabled bool) *GuildQueryState {
	if state, exists := c.GetQueryState(queryID); exists {
		return state
	}
	
	state := NewGuildQueryState(c.GuildID, queryID, enabled)
	c.SetQueryState(queryID, state)
	return state
}

// EnableQuery enables a query
func (c *GuildConfig) EnableQuery(queryID string) {
	if state, exists := c.GetQueryState(queryID); exists {
		state.Enabled = true
		c.LastUpdated = time.Now()
	}
}

// DisableQuery disables a query
func (c *GuildConfig) DisableQuery(queryID string) {
	if state, exists := c.GetQueryState(queryID); exists {
		state.Enabled = false
		c.LastUpdated = time.Now()
	}
}

// GetEnabledQueries returns all enabled query IDs
func (c *GuildConfig) GetEnabledQueries() []string {
	var enabled []string
	if c.QueryStates != nil {
		for queryID, state := range c.QueryStates {
			if state.Enabled {
				enabled = append(enabled, queryID)
			}
		}
	}
	return enabled
}

// DeleteQueryState removes a query state
func (c *GuildConfig) DeleteQueryState(queryID string) {
	if c.QueryStates != nil {
		delete(c.QueryStates, queryID)
		c.LastUpdated = time.Now()
	}
}

// GuildQueryState helper methods

// UpdateLastProcessedBlock updates the last processed block height
func (gqs *GuildQueryState) UpdateLastProcessedBlock(height int64) {
	if height > gqs.LastProcessedBlock {
		gqs.LastProcessedBlock = height
		gqs.LastProcessedTxIndex = 0 // Reset transaction index when moving to new block
	}
}

// UpdateProcessingPosition updates both block height and transaction index
func (gqs *GuildQueryState) UpdateProcessingPosition(blockHeight int64, txIndex int64) {
	if blockHeight > gqs.LastProcessedBlock {
		gqs.LastProcessedBlock = blockHeight
		gqs.LastProcessedTxIndex = txIndex
	} else if blockHeight == gqs.LastProcessedBlock && txIndex > gqs.LastProcessedTxIndex {
		gqs.LastProcessedTxIndex = txIndex
	}
}

// GetProcessingPosition returns the current processing position
func (gqs *GuildQueryState) GetProcessingPosition() (blockHeight int64, txIndex int64) {
	return gqs.LastProcessedBlock, gqs.LastProcessedTxIndex
}

// SetExecuting sets the execution state
func (gqs *GuildQueryState) SetExecuting(executing bool) {
	gqs.IsExecuting = executing
}

// UpdateRunTimestamp updates the last run timestamp and calculates next run
func (gqs *GuildQueryState) UpdateRunTimestamp(interval time.Duration) {
	gqs.LastRunTimestamp = time.Now()
	gqs.NextRunTimestamp = gqs.LastRunTimestamp.Add(interval)
}

// RecordError records an error for this query state
func (gqs *GuildQueryState) RecordError(err error) {
	gqs.ErrorCount++
	gqs.LastError = err.Error()
	gqs.LastErrorTime = time.Now()
}

// ClearErrors clears the error state
func (gqs *GuildQueryState) ClearErrors() {
	gqs.ErrorCount = 0
	gqs.LastError = ""
	gqs.LastErrorTime = time.Time{}
}

// IsReady returns true if the query is ready to run
func (gqs *GuildQueryState) IsReady() bool {
	return gqs.Enabled && 
		!gqs.IsExecuting && // Check not already running
		time.Now().After(gqs.NextRunTimestamp)
}

// SetState sets a query-specific state value
func (gqs *GuildQueryState) SetState(key string, value any) {
	if gqs.State == nil {
		gqs.State = make(map[string]any)
	}
	gqs.State[key] = value
}

// GetState gets a query-specific state value
func (gqs *GuildQueryState) GetState(key string) (any, bool) {
	if gqs.State == nil {
		return nil, false
	}
	value, exists := gqs.State[key]
	return value, exists
}

// GetStateString gets a query-specific state value as string
func (gqs *GuildQueryState) GetStateString(key string) (string, bool) {
	value, exists := gqs.GetState(key)
	if !exists {
		return "", false
	}
	if strValue, ok := value.(string); ok {
		return strValue, true
	}
	return "", false
}

// GetStateInt64 gets a query-specific state value as int64
func (gqs *GuildQueryState) GetStateInt64(key string) (int64, bool) {
	value, exists := gqs.GetState(key)
	if !exists {
		return 0, false
	}
	if intValue, ok := value.(int64); ok {
		return intValue, true
	}
	return 0, false
}