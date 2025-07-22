package events

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/graphql"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
)

// contextKey is a custom type for context keys to avoid collisions
type contextKey string

// saveCallbackKey is the context key for the save callback function
const saveCallbackKey contextKey = "saveCallback"

// QueryProcessor manages query execution for a specific guild
type QueryProcessor struct {
	guildID               string
	registry              *QueryRegistry
	store                 storage.ConfigStore
	queryClient           *graphql.QueryClient
	queryExecutor         *QueryExecutor
	verificationScheduler *VerificationScheduler
	logger                core.Logger
	ctx                   context.Context
	cancel                context.CancelFunc
	wg                    sync.WaitGroup
	running               bool
	mutex                 sync.RWMutex
}

// QueryProcessorManager manages all query processors
type QueryProcessorManager struct {
	processors    map[string]*QueryProcessor
	registry      *QueryRegistry
	store         storage.ConfigStore
	queryClient   *graphql.QueryClient
	eventHandlers *EventHandlers
	logger        core.Logger
	ctx           context.Context
	cancel        context.CancelFunc
	wg            sync.WaitGroup
	mutex         sync.RWMutex
}

// NewQueryProcessorManager creates a new query processor manager
func NewQueryProcessorManager(registry *QueryRegistry, store storage.ConfigStore, queryClient *graphql.QueryClient, eventHandlers *EventHandlers, logger core.Logger) *QueryProcessorManager {
	return &QueryProcessorManager{
		processors:    make(map[string]*QueryProcessor),
		registry:      registry,
		store:         store,
		queryClient:   queryClient,
		eventHandlers: eventHandlers,
		logger:        logger,
	}
}

// Start starts the query processor manager
func (qpm *QueryProcessorManager) Start(ctx context.Context) error {
	qpm.mutex.Lock()
	defer qpm.mutex.Unlock()

	qpm.ctx, qpm.cancel = context.WithCancel(ctx)
	qpm.logger.Info("Starting query processor manager")

	// Start processors for existing guilds
	if err := qpm.startProcessorsForExistingGuilds(); err != nil {
		qpm.logger.Error("Failed to start processors for existing guilds", "error", err)
		return err
	}

	qpm.logger.Info("Query processor manager started")
	return nil
}

// Stop stops the query processor manager
func (qpm *QueryProcessorManager) Stop() error {
	qpm.mutex.Lock()
	defer qpm.mutex.Unlock()

	qpm.logger.Info("Stopping query processor manager")

	if qpm.cancel != nil {
		qpm.cancel()
	}

	// Stop all processors
	for guildID, processor := range qpm.processors {
		qpm.logger.Info("Stopping processor for guild", "guild_id", guildID)
		if err := processor.Stop(); err != nil {
			qpm.logger.Error("Failed to stop processor", "guild_id", guildID, "error", err)
		}
	}

	// Wait for all processors to stop
	qpm.wg.Wait()

	qpm.logger.Info("Query processor manager stopped")
	return nil
}

// AddGuild adds a new guild processor
func (qpm *QueryProcessorManager) AddGuild(guildID string) error {
	qpm.mutex.Lock()
	defer qpm.mutex.Unlock()

	if _, exists := qpm.processors[guildID]; exists {
		return fmt.Errorf("processor for guild %s already exists", guildID)
	}

	processor := NewQueryProcessor(guildID, qpm.registry, qpm.store, qpm.queryClient, qpm.eventHandlers, qpm.logger)
	qpm.processors[guildID] = processor

	if qpm.ctx != nil {
		qpm.wg.Add(1)
		go func() {
			defer qpm.wg.Done()
			if err := processor.Start(qpm.ctx); err != nil {
				qpm.logger.Error("Failed to start processor", "guild_id", guildID, "error", err)
			}
		}()
	}

	qpm.logger.Info("Added guild processor", "guild_id", guildID)
	return nil
}

// RemoveGuild removes a guild processor
func (qpm *QueryProcessorManager) RemoveGuild(guildID string) error {
	qpm.mutex.Lock()
	defer qpm.mutex.Unlock()

	processor, exists := qpm.processors[guildID]
	if !exists {
		return fmt.Errorf("processor for guild %s does not exist", guildID)
	}

	if err := processor.Stop(); err != nil {
		qpm.logger.Error("Failed to stop processor", "guild_id", guildID, "error", err)
	}

	delete(qpm.processors, guildID)
	qpm.logger.Info("Removed guild processor", "guild_id", guildID)
	return nil
}

// GetProcessor retrieves a processor for a specific guild
func (qpm *QueryProcessorManager) GetProcessor(guildID string) (*QueryProcessor, bool) {
	qpm.mutex.RLock()
	defer qpm.mutex.RUnlock()

	processor, exists := qpm.processors[guildID]
	return processor, exists
}

// startProcessorsForExistingGuilds starts processors for all existing guilds
func (qpm *QueryProcessorManager) startProcessorsForExistingGuilds() error {
	// This would need to be implemented to discover existing guilds
	// For now, we'll leave it as a placeholder
	qpm.logger.Info("Starting processors for existing guilds - placeholder implementation")
	return nil
}

// NewQueryProcessor creates a new query processor for a guild
func NewQueryProcessor(guildID string, registry *QueryRegistry, store storage.ConfigStore, queryClient *graphql.QueryClient, eventHandlers *EventHandlers, logger core.Logger) *QueryProcessor {
	return &QueryProcessor{
		guildID:               guildID,
		registry:              registry,
		store:                 store,
		queryClient:           queryClient,
		queryExecutor:         NewQueryExecutor(queryClient, logger),
		verificationScheduler: NewVerificationScheduler(guildID, store, eventHandlers, logger),
		logger:                logger,
	}
}

// Start starts the query processor
func (qp *QueryProcessor) Start(ctx context.Context) error {
	qp.mutex.Lock()
	defer qp.mutex.Unlock()

	if qp.running {
		return fmt.Errorf("processor for guild %s is already running", qp.guildID)
	}

	qp.ctx, qp.cancel = context.WithCancel(ctx)
	qp.running = true

	qp.logger.Info("Starting query processor", "guild_id", qp.guildID)

	// Start query execution loop
	qp.wg.Add(1)
	go qp.queryLoop()

	// Start verification scheduler
	if qp.verificationScheduler != nil {
		if err := qp.verificationScheduler.Start(qp.ctx); err != nil {
			qp.logger.Error("Failed to start verification scheduler", "guild_id", qp.guildID, "error", err)
			// Continue anyway - queries can still run
		}
	}

	qp.logger.Info("Query processor started", "guild_id", qp.guildID)
	return nil
}

// Stop stops the query processor
func (qp *QueryProcessor) Stop() error {
	qp.mutex.Lock()
	defer qp.mutex.Unlock()

	if !qp.running {
		return nil
	}

	qp.logger.Info("Stopping query processor", "guild_id", qp.guildID)

	// Stop verification scheduler first
	if qp.verificationScheduler != nil {
		if err := qp.verificationScheduler.Stop(); err != nil {
			qp.logger.Error("Failed to stop verification scheduler", "guild_id", qp.guildID, "error", err)
		}
	}

	if qp.cancel != nil {
		qp.cancel()
	}

	qp.running = false

	// Wait for query loop to finish
	qp.wg.Wait()

	qp.logger.Info("Query processor stopped", "guild_id", qp.guildID)
	return nil
}

// queryLoop is the main query execution loop
func (qp *QueryProcessor) queryLoop() {
	defer qp.wg.Done()

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	qp.logger.Info("Starting query loop", "guild_id", qp.guildID)

	for {
		select {
		case <-qp.ctx.Done():
			qp.logger.Info("Query loop stopped", "guild_id", qp.guildID)
			return
		case <-ticker.C:
			qp.processQueries()
		}
	}
}

// processQueries processes all enabled queries for the guild
func (qp *QueryProcessor) processQueries() {
	config, err := qp.store.Get(qp.guildID)
	if err != nil {
		qp.logger.Error("Failed to get guild config", "guild_id", qp.guildID, "error", err)
		return
	}

	// Clean up old verification queries that are no longer used
	// These are now handled by VerificationScheduler
	obsoleteQueries := []string{"verify_high_priority", "verify_medium_priority", "verify_low_priority", "verify_members"}
	configModified := false
	for _, queryID := range obsoleteQueries {
		if _, exists := config.GetQueryState(queryID); exists {
			qp.logger.Info("Removing obsolete verification query from config", "guild_id", qp.guildID, "query_id", queryID)
			config.DisableQuery(queryID)
			delete(config.QueryStates, queryID)
			configModified = true
		}
	}

	// Ensure core event queries are enabled by default
	// Note: Verification is now handled by VerificationScheduler, not as queries
	coreQueries := []string{"user_events", "role_events"}
	for _, queryID := range coreQueries {
		if _, exists := config.GetQueryState(queryID); !exists {
			qp.logger.Info("Enabling core query for guild", "guild_id", qp.guildID, "query_id", queryID)
			config.EnsureQueryState(queryID, true)
			configModified = true
		}
	}

	// Save the updated config if we made any changes
	if configModified {
		if err := qp.store.Set(qp.guildID, config); err != nil {
			qp.logger.Error("Failed to save config after updating queries", "guild_id", qp.guildID, "error", err)
		}
	}

	// Get enabled queries
	enabledQueries := config.GetEnabledQueries()
	qp.logger.Debug("Processing queries for guild", "guild_id", qp.guildID, "enabled_queries", enabledQueries, "enabled_count", len(enabledQueries))

	// Process each enabled query
	for _, queryID := range enabledQueries {
		qp.logger.Debug("Processing query", "guild_id", qp.guildID, "query_id", queryID)
		if err := qp.processQuery(queryID, config); err != nil {
			qp.logger.Error("Failed to process query", "guild_id", qp.guildID, "query_id", queryID, "error", err)
		}
	}
}

// processQuery processes a single query
func (qp *QueryProcessor) processQuery(queryID string, config *storage.GuildConfig) error {
	// Get query definition
	queryDef, exists := qp.registry.GetQuery(queryID)
	if !exists {
		return fmt.Errorf("query definition not found: %s", queryID)
	}

	// Get query state
	queryState, exists := config.GetQueryState(queryID)
	if !exists {
		// Create new query state if it doesn't exist
		queryState = config.EnsureQueryState(queryID, true)
	}

	// Check if query is ready to run
	if !queryState.IsReady() {
		return nil
	}

	// Set execution state to prevent concurrent runs
	queryState.SetExecuting(true)
	// Save the state immediately to prevent race conditions
	if err := qp.store.Set(qp.guildID, config); err != nil {
		qp.logger.Error("Failed to save execution state", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "error", err)
		return err
	}

	// Ensure we clear execution state when done
	defer func() {
		queryState.SetExecuting(false)
		if err := qp.store.Set(qp.guildID, config); err != nil {
			qp.logger.Error("Failed to clear execution state", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "error", err)
		}
	}()

	// Check if query is event stream type and needs block height processing
	if queryDef.QueryType == EventStreamQuery {
		return qp.processEventStreamQuery(queryDef, queryState, config)
	}

	// For other query types (periodic, on-demand), process them differently
	return qp.processGenericQuery(queryDef, queryState, config)
}

// processEventStreamQuery processes an event stream query
func (qp *QueryProcessor) processEventStreamQuery(queryDef *QueryDefinition, queryState *storage.GuildQueryState, config *storage.GuildConfig) error {
	qp.logger.Debug("Processing event stream query", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "last_block", queryState.LastProcessedBlock)

	// Execute the query
	results, err := qp.queryExecutor.ExecuteQuery(qp.ctx, queryDef, queryState)
	if err != nil {
		qp.logger.Error("Failed to execute query", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "error", err)
		queryState.RecordError(err)
		// Still update timestamp to avoid hammering failed queries
		queryState.UpdateRunTimestamp(queryDef.Interval)
		return qp.store.Set(qp.guildID, config)
	}

	// Process results and save position incrementally
	if len(results) > 0 && queryDef.Handler != nil {
		// Create a save callback for incremental state saving
		saveCallback := func() error {
			return qp.store.Set(qp.guildID, config)
		}

		// Create a wrapper that provides the save callback to the handler
		wrappedHandler := func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState) error {
			// Set the save callback in the context for handlers to use
			ctxWithSave := context.WithValue(ctx, saveCallbackKey, saveCallback)

			// Call the handler
			if err := queryDef.Handler(ctxWithSave, results, guild, state); err != nil {
				return err
			}

			// Save at the end (fallback if handler didn't save incrementally)
			return saveCallback()
		}

		if err := wrappedHandler(qp.ctx, results, config, queryState); err != nil {
			qp.logger.Error("Query handler failed", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "error", err)
			queryState.RecordError(err)
			// Position was saved up to the last successful transaction
		} else {
			qp.logger.Info("Query handler completed successfully", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "results_count", len(results))
			queryState.ClearErrors()
		}
	}

	// Update run timestamp
	queryState.UpdateRunTimestamp(queryDef.Interval)

	// Save updated config (final save for timestamp update)
	return qp.store.Set(qp.guildID, config)
}

// processGenericQuery processes non-event-stream queries (periodic, on-demand)
func (qp *QueryProcessor) processGenericQuery(queryDef *QueryDefinition, queryState *storage.GuildQueryState, config *storage.GuildConfig) error {
	qp.logger.Debug("Processing generic query", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "query_type", queryDef.QueryType)

	// Execute the query
	results, err := qp.queryExecutor.ExecuteQuery(qp.ctx, queryDef, queryState)
	if err != nil {
		qp.logger.Error("Failed to execute query", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "error", err)
		queryState.RecordError(err)
		// Still update timestamp to avoid hammering failed queries
		queryState.UpdateRunTimestamp(queryDef.Interval)
		return qp.store.Set(qp.guildID, config)
	}

	// Call the query handler
	if queryDef.Handler != nil {
		if err := queryDef.Handler(qp.ctx, results, config, queryState); err != nil {
			qp.logger.Error("Query handler failed", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "error", err)
			queryState.RecordError(err)
		} else {
			qp.logger.Info("Query handler completed successfully", "guild_id", qp.guildID, "query_id", queryDef.QueryID, "results_count", len(results))
			queryState.ClearErrors()
		}
	}

	// Update run timestamp
	queryState.UpdateRunTimestamp(queryDef.Interval)

	// Save updated config
	return qp.store.Set(qp.guildID, config)
}

// EnableQuery enables a query for the guild
func (qp *QueryProcessor) EnableQuery(queryID string) error {
	config, err := qp.store.Get(qp.guildID)
	if err != nil {
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	config.EnableQuery(queryID)
	return qp.store.Set(qp.guildID, config)
}

// DisableQuery disables a query for the guild
func (qp *QueryProcessor) DisableQuery(queryID string) error {
	config, err := qp.store.Get(qp.guildID)
	if err != nil {
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	config.DisableQuery(queryID)
	return qp.store.Set(qp.guildID, config)
}

// GetQueryState retrieves the current state of a query
func (qp *QueryProcessor) GetQueryState(queryID string) (*storage.GuildQueryState, error) {
	config, err := qp.store.Get(qp.guildID)
	if err != nil {
		return nil, fmt.Errorf("failed to get guild config: %w", err)
	}

	queryState, exists := config.GetQueryState(queryID)
	if !exists {
		return nil, fmt.Errorf("query state not found: %s", queryID)
	}

	return queryState, nil
}
