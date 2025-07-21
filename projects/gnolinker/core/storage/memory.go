package storage

import (
	"errors"
	"sync"
	"time"
)

// MemoryConfigStore provides an in-memory implementation of ConfigStore
// Useful for testing and as a fallback when blob storage is unavailable
type MemoryConfigStore struct {
	configs      map[string]*GuildConfig
	globalConfig *GlobalConfig
	mutex        sync.RWMutex
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
		return nil, ErrGuildConfigNotFound
	}

	// Return a copy to prevent external modification
	configCopy := *config
	if config.Settings != nil {
		configCopy.Settings = make(map[string]string)
		for k, v := range config.Settings {
			configCopy.Settings[k] = v
		}
	}

	// Deep copy the query states map
	if config.QueryStates != nil {
		configCopy.QueryStates = make(map[string]*GuildQueryState, len(config.QueryStates))
		for k, v := range config.QueryStates {
			if v != nil {
				// Deep copy the query state
				queryCopy := &GuildQueryState{
					GuildID:            v.GuildID,
					QueryID:            v.QueryID,
					LastProcessedBlock: v.LastProcessedBlock,
					LastRunTimestamp:   v.LastRunTimestamp,
					NextRunTimestamp:   v.NextRunTimestamp,
					Enabled:            v.Enabled,
					ErrorCount:         v.ErrorCount,
					LastError:          v.LastError,
					LastErrorTime:      v.LastErrorTime,
				}

				// Deep copy the state map if it exists
				if v.State != nil {
					queryCopy.State = make(map[string]any, len(v.State))
					for sk, sv := range v.State {
						queryCopy.State[sk] = sv
					}
				}

				configCopy.QueryStates[k] = queryCopy
			}
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

	// Deep copy the query states map
	if config.QueryStates != nil {
		configCopy.QueryStates = make(map[string]*GuildQueryState, len(config.QueryStates))
		for k, v := range config.QueryStates {
			if v != nil {
				// Deep copy the query state
				queryCopy := &GuildQueryState{
					GuildID:            v.GuildID,
					QueryID:            v.QueryID,
					LastProcessedBlock: v.LastProcessedBlock,
					LastRunTimestamp:   v.LastRunTimestamp,
					NextRunTimestamp:   v.NextRunTimestamp,
					Enabled:            v.Enabled,
					ErrorCount:         v.ErrorCount,
					LastError:          v.LastError,
					LastErrorTime:      v.LastErrorTime,
				}

				// Deep copy the state map if it exists
				if v.State != nil {
					queryCopy.State = make(map[string]any, len(v.State))
					for sk, sv := range v.State {
						queryCopy.State[sk] = sv
					}
				}

				configCopy.QueryStates[k] = queryCopy
			}
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
	s.globalConfig = nil
}

// GetGlobal retrieves the global configuration
func (s *MemoryConfigStore) GetGlobal() (*GlobalConfig, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	if s.globalConfig == nil {
		// Return default global config if none exists
		return &GlobalConfig{
			ConfigID:                 "global",
			LastProcessedBlockHeight: 0,
			LastUpdated:              time.Now(),
		}, nil
	}

	// Return a copy to prevent external modification
	return &GlobalConfig{
		ConfigID:                 s.globalConfig.ConfigID,
		LastProcessedBlockHeight: s.globalConfig.LastProcessedBlockHeight,
		LastUpdated:              s.globalConfig.LastUpdated,
	}, nil
}

// SetGlobal stores the global configuration
func (s *MemoryConfigStore) SetGlobal(config *GlobalConfig) error {
	if config == nil {
		return errors.New("global config cannot be nil")
	}

	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Store a copy to prevent external modification
	s.globalConfig = &GlobalConfig{
		ConfigID:                 config.ConfigID,
		LastProcessedBlockHeight: config.LastProcessedBlockHeight,
		LastUpdated:              config.LastUpdated,
	}

	return nil
}
