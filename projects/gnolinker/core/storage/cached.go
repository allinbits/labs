package storage

import (
	"sync"
	"time"

	lru "github.com/hashicorp/golang-lru/v2"
)

// CachedConfigStore wraps any ConfigStore with an LRU cache for improved performance
type CachedConfigStore struct {
	backend   ConfigStore
	cache     *lru.Cache[string, *cachedConfig]
	ttl       time.Duration
	mutex     sync.RWMutex
}

// cachedConfig holds a config with its cache timestamp
type cachedConfig struct {
	config    *GuildConfig
	cachedAt  time.Time
}

// CacheConfig holds the configuration for the cache
type CacheConfig struct {
	Size int           // Maximum number of entries to cache
	TTL  time.Duration // Time-to-live for cached entries
}

// NewCachedConfigStore creates a new cached config store
func NewCachedConfigStore(backend ConfigStore, config CacheConfig) (*CachedConfigStore, error) {
	if config.Size <= 0 {
		config.Size = 100 // Default cache size
	}
	if config.TTL <= 0 {
		config.TTL = time.Hour // Default TTL of 1 hour
	}

	cache, err := lru.New[string, *cachedConfig](config.Size)
	if err != nil {
		return nil, err
	}

	return &CachedConfigStore{
		backend: backend,
		cache:   cache,
		ttl:     config.TTL,
	}, nil
}

// Get retrieves a guild configuration, checking cache first
func (s *CachedConfigStore) Get(guildID string) (*GuildConfig, error) {
	s.mutex.RLock()
	cached, exists := s.cache.Get(guildID)
	s.mutex.RUnlock()

	// Check if we have a valid cached entry
	if exists && time.Since(cached.cachedAt) < s.ttl {
		// Return a copy to prevent external modification
		return s.copyConfig(cached.config), nil
	}

	// Cache miss or expired, fetch from backend
	config, err := s.backend.Get(guildID)
	if err != nil {
		return nil, err
	}

	// Store in cache
	s.mutex.Lock()
	s.cache.Add(guildID, &cachedConfig{
		config:   s.copyConfig(config),
		cachedAt: time.Now(),
	})
	s.mutex.Unlock()

	return config, nil
}

// Set stores a guild configuration in both cache and backend
func (s *CachedConfigStore) Set(guildID string, config *GuildConfig) error {
	if config == nil {
		return nil
	}

	// Store in backend first
	err := s.backend.Set(guildID, config)
	if err != nil {
		return err
	}

	// Update cache
	s.mutex.Lock()
	s.cache.Add(guildID, &cachedConfig{
		config:   s.copyConfig(config),
		cachedAt: time.Now(),
	})
	s.mutex.Unlock()

	return nil
}

// Delete removes a guild configuration from both cache and backend
func (s *CachedConfigStore) Delete(guildID string) error {
	// Remove from backend first
	err := s.backend.Delete(guildID)
	if err != nil {
		return err
	}

	// Remove from cache
	s.mutex.Lock()
	s.cache.Remove(guildID)
	s.mutex.Unlock()

	return nil
}

// InvalidateCache removes an entry from the cache, forcing next Get to fetch from backend
func (s *CachedConfigStore) InvalidateCache(guildID string) {
	s.mutex.Lock()
	s.cache.Remove(guildID)
	s.mutex.Unlock()
}

// ClearCache removes all entries from the cache
func (s *CachedConfigStore) ClearCache() {
	s.mutex.Lock()
	s.cache.Purge()
	s.mutex.Unlock()
}

// CacheStats returns cache statistics
func (s *CachedConfigStore) CacheStats() int {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return s.cache.Len()
}

// copyConfig creates a deep copy of a GuildConfig to prevent external modification
func (s *CachedConfigStore) copyConfig(config *GuildConfig) *GuildConfig {
	if config == nil {
		return nil
	}

	copy := &GuildConfig{
		GuildID:        config.GuildID,
		AdminRoleID:    config.AdminRoleID,
		VerifiedRoleID: config.VerifiedRoleID,
		LastUpdated:    config.LastUpdated,
	}

	// Deep copy the settings map
	if config.Settings != nil {
		copy.Settings = make(map[string]string, len(config.Settings))
		for k, v := range config.Settings {
			copy.Settings[k] = v
		}
	}

	// Deep copy the query states map
	if config.QueryStates != nil {
		copy.QueryStates = make(map[string]*GuildQueryState, len(config.QueryStates))
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
				
				copy.QueryStates[k] = queryCopy
			}
		}
	}

	return copy
}

// RefreshCache forces a refresh of a specific guild's config from the backend
func (s *CachedConfigStore) RefreshCache(guildID string) (*GuildConfig, error) {
	// Remove from cache first
	s.InvalidateCache(guildID)
	
	// Fetch fresh from backend, which will also populate cache
	return s.Get(guildID)
}

// GetGlobal retrieves the global configuration from the backend
func (s *CachedConfigStore) GetGlobal() (*GlobalConfig, error) {
	// Global config is not cached as it's accessed infrequently
	return s.backend.GetGlobal()
}

// SetGlobal stores the global configuration in the backend
func (s *CachedConfigStore) SetGlobal(config *GlobalConfig) error {
	// Global config is not cached as it's accessed infrequently
	return s.backend.SetGlobal(config)
}