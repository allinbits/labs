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

// GuildConfig represents the configuration for a Discord guild
type GuildConfig struct {
	GuildID        string            `json:"guild_id"`
	AdminRoleID    string            `json:"admin_role_id,omitempty"`
	VerifiedRoleID string            `json:"verified_role_id,omitempty"`
	Settings       map[string]string `json:"settings,omitempty"`
	LastUpdated    time.Time         `json:"last_updated"`
	
	// ETag is used for optimistic concurrency control
	// Not serialized to JSON - managed by storage layer
	ETag string `json:"-"`
}

// ConfigStore defines the interface for guild configuration storage
type ConfigStore interface {
	Get(guildID string) (*GuildConfig, error)
	Set(guildID string, config *GuildConfig) error
	Delete(guildID string) error
}

// NewGuildConfig creates a new guild configuration with default values
func NewGuildConfig(guildID string) *GuildConfig {
	return &GuildConfig{
		GuildID:     guildID,
		Settings:    make(map[string]string),
		LastUpdated: time.Now(),
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