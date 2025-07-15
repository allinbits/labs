package storage

import (
	"errors"
	"sync"
)

// MemoryConfigStore provides an in-memory implementation of ConfigStore
// Useful for testing and as a fallback when blob storage is unavailable
type MemoryConfigStore struct {
	configs map[string]*GuildConfig
	mutex   sync.RWMutex
}

// NewMemoryConfigStore creates a new in-memory config store
func NewMemoryConfigStore() *MemoryConfigStore {
	return &MemoryConfigStore{
		configs: make(map[string]*GuildConfig),
	}
}

// Get retrieves a guild configuration by guild ID
func (s *MemoryConfigStore) Get(guildID string) (*GuildConfig, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	
	config, exists := s.configs[guildID]
	if !exists {
		return nil, errors.New("guild config not found")
	}
	
	// Return a copy to prevent external modification
	configCopy := *config
	if config.Settings != nil {
		configCopy.Settings = make(map[string]string)
		for k, v := range config.Settings {
			configCopy.Settings[k] = v
		}
	}
	
	return &configCopy, nil
}

// Set stores a guild configuration
func (s *MemoryConfigStore) Set(guildID string, config *GuildConfig) error {
	if config == nil {
		return errors.New("config cannot be nil")
	}
	
	s.mutex.Lock()
	defer s.mutex.Unlock()
	
	// Store a copy to prevent external modification
	configCopy := *config
	if config.Settings != nil {
		configCopy.Settings = make(map[string]string)
		for k, v := range config.Settings {
			configCopy.Settings[k] = v
		}
	}
	
	s.configs[guildID] = &configCopy
	return nil
}

// Delete removes a guild configuration
func (s *MemoryConfigStore) Delete(guildID string) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	
	delete(s.configs, guildID)
	return nil
}

// Count returns the number of stored configurations (useful for testing)
func (s *MemoryConfigStore) Count() int {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return len(s.configs)
}

// Clear removes all configurations (useful for testing)
func (s *MemoryConfigStore) Clear() {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	s.configs = make(map[string]*GuildConfig)
}