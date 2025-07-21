package events

import (
	"context"
	"fmt"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/graphql"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
)

// Query IDs
const (
	UserEventsQueryID           = "user_events"            // All events from user package in chronological order
	RoleEventsQueryID           = "role_events"            // All events from role package in chronological order
	VerifyHighPriorityQueryID   = "verify_high_priority"   // Verify online/active users frequently
	VerifyMediumPriorityQueryID = "verify_medium_priority" // Verify recently active users
	VerifyLowPriorityQueryID    = "verify_low_priority"    // Verify inactive/offline users
)

// CreateCoreQueryRegistry creates and registers all core queries
func CreateCoreQueryRegistry(logger core.Logger, eventHandlers *EventHandlers) *QueryRegistry {
	registry := NewQueryRegistry()

	// Register user events query (UserLinked and UserUnlinked in chronological order)
	registry.RegisterQuery(&QueryDefinition{
		QueryID:      UserEventsQueryID,
		Name:         "User Events",
		Description:  "Monitors blockchain for UserLinked and UserUnlinked events in chronological order",
		QueryType:    EventStreamQuery,
		GraphQLQuery: `query UserEvents { getTransactions(where: { success: { eq: true } response: { events: { GnoEvent: { pkg_path: { eq: "gno.land/r/linker000/discord/user/v0" } } } } } order: { heightAndIndex: ASC }) { hash index block_height messages { value { ... on MsgCall { func } } } response { events { ... on GnoEvent { type pkg_path attrs { key value } } } } } }`,
		Interval:     5 * time.Second,
		Handler:      createUserEventsHandler(logger, eventHandlers),
		Enabled:      true,
	})

	// Register role events query (RoleLinked and RoleUnlinked in chronological order)
	registry.RegisterQuery(&QueryDefinition{
		QueryID:      RoleEventsQueryID,
		Name:         "Role Events",
		Description:  "Monitors blockchain for RoleLinked and RoleUnlinked events in chronological order",
		QueryType:    EventStreamQuery,
		GraphQLQuery: `query RoleEvents { getTransactions(where: { success: { eq: true } response: { events: { GnoEvent: { pkg_path: { eq: "gno.land/r/linker000/discord/role/v0" } } } } } order: { heightAndIndex: ASC }) { hash index block_height messages { value { ... on MsgCall { func } } } response { events { ... on GnoEvent { type pkg_path attrs { key value } } } } } }`,
		Interval:     5 * time.Second,
		Handler:      createRoleEventsHandler(logger, eventHandlers),
		Enabled:      true,
	})

	// Register high priority verification query - online/active users
	registry.RegisterQuery(&QueryDefinition{
		QueryID:      VerifyHighPriorityQueryID,
		Name:         "Verify High Priority Members",
		Description:  "Verifies online/active guild members against Gno realm state",
		QueryType:    PeriodicCheckQuery,
		GraphQLQuery: "",              // Uses QEval to query Gno realms directly
		Interval:     1 * time.Minute, // Check online users every minute
		Handler:      createVerifyHighPriorityHandler(logger, eventHandlers),
		Enabled:      true,
	})

	// Register medium priority verification query - recently active users
	registry.RegisterQuery(&QueryDefinition{
		QueryID:      VerifyMediumPriorityQueryID,
		Name:         "Verify Medium Priority Members",
		Description:  "Verifies recently active guild members against Gno realm state",
		QueryType:    PeriodicCheckQuery,
		GraphQLQuery: "",              // Uses QEval to query Gno realms directly
		Interval:     5 * time.Minute, // Check recently active users every 5 minutes
		Handler:      createVerifyMediumPriorityHandler(logger, eventHandlers),
		Enabled:      true,
	})

	// Register low priority verification query - inactive/offline users
	registry.RegisterQuery(&QueryDefinition{
		QueryID:      VerifyLowPriorityQueryID,
		Name:         "Verify Low Priority Members",
		Description:  "Verifies inactive/offline guild members against Gno realm state incrementally",
		QueryType:    PeriodicCheckQuery,
		GraphQLQuery: "",               // Uses QEval to query Gno realms directly
		Interval:     30 * time.Minute, // Check inactive users every 30 minutes
		Handler:      createVerifyLowPriorityHandler(logger, eventHandlers),
		Enabled:      true,
	})

	return registry
}

// createVerifyHighPriorityHandler creates a handler for high priority member verification (online/active users)
func createVerifyHighPriorityHandler(logger core.Logger, eventHandlers *EventHandlers) QueryHandler {
	return func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState) error {
		logger.Info("Processing VerifyHighPriority query", "guild_id", guild.GuildID)

		if eventHandlers == nil {
			logger.Error("EventHandlers not available for VerifyHighPriority", "guild_id", guild.GuildID)
			return nil
		}

		// Process high priority users (online/active) - no user limit
		if err := eventHandlers.ProcessTieredVerification(ctx, guild.GuildID, state, "high", 0); err != nil {
			logger.Error("Failed to process high priority verification",
				"guild_id", guild.GuildID,
				"error", err,
			)
			return err
		}

		logger.Info("Completed VerifyHighPriority processing", "guild_id", guild.GuildID)
		return nil
	}
}

// createVerifyMediumPriorityHandler creates a handler for medium priority member verification (recently active users)
func createVerifyMediumPriorityHandler(logger core.Logger, eventHandlers *EventHandlers) QueryHandler {
	return func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState) error {
		logger.Info("Processing VerifyMediumPriority query", "guild_id", guild.GuildID)

		if eventHandlers == nil {
			logger.Error("EventHandlers not available for VerifyMediumPriority", "guild_id", guild.GuildID)
			return nil
		}

		// Process medium priority users (recently active) - up to 20 users
		if err := eventHandlers.ProcessTieredVerification(ctx, guild.GuildID, state, "medium", 20); err != nil {
			logger.Error("Failed to process medium priority verification",
				"guild_id", guild.GuildID,
				"error", err,
			)
			return err
		}

		logger.Info("Completed VerifyMediumPriority processing", "guild_id", guild.GuildID)
		return nil
	}
}

// createVerifyLowPriorityHandler creates a handler for low priority member verification (inactive/offline users)
func createVerifyLowPriorityHandler(logger core.Logger, eventHandlers *EventHandlers) QueryHandler {
	return func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState) error {
		logger.Info("Processing VerifyLowPriority query", "guild_id", guild.GuildID)

		if eventHandlers == nil {
			logger.Error("EventHandlers not available for VerifyLowPriority", "guild_id", guild.GuildID)
			return nil
		}

		// Process low priority users (inactive/offline) incrementally - up to 10 users
		if err := eventHandlers.ProcessTieredVerification(ctx, guild.GuildID, state, "low", 10); err != nil {
			logger.Error("Failed to process low priority verification",
				"guild_id", guild.GuildID,
				"error", err,
			)
			return err
		}

		logger.Info("Completed VerifyLowPriority processing", "guild_id", guild.GuildID)
		return nil
	}
}

// QueryExecutor handles the execution of queries
type QueryExecutor struct {
	queryClient *graphql.QueryClient
	logger      core.Logger
}

// NewQueryExecutor creates a new query executor
func NewQueryExecutor(queryClient *graphql.QueryClient, logger core.Logger) *QueryExecutor {
	return &QueryExecutor{
		queryClient: queryClient,
		logger:      logger,
	}
}

// ExecuteQuery executes a query and returns results
func (qe *QueryExecutor) ExecuteQuery(ctx context.Context, queryDef *QueryDefinition, queryState *storage.GuildQueryState) ([]any, error) {
	switch queryDef.QueryID {
	case UserEventsQueryID:
		return qe.executeUserEventsQuery(ctx, queryState)
	case RoleEventsQueryID:
		return qe.executeRoleEventsQuery(ctx, queryState)
	case VerifyHighPriorityQueryID, VerifyMediumPriorityQueryID, VerifyLowPriorityQueryID:
		return qe.executeVerifyMembersQuery(ctx, queryState)
	default:
		return nil, fmt.Errorf("unknown query ID: %s", queryDef.QueryID)
	}
}

// executeUserEventsQuery executes the user events query
func (qe *QueryExecutor) executeUserEventsQuery(ctx context.Context, queryState *storage.GuildQueryState) ([]any, error) {
	// Get current block height from indexer
	currentHeight, err := qe.queryClient.QueryLatestBlockHeight(ctx)
	if err != nil {
		qe.logger.Error("Failed to get current block height from indexer", "error", err)
		return nil, fmt.Errorf("failed to get current block height from indexer: %w", err)
	}

	// Check if chain was reset - if indexer height < last processed, reset to 0
	if currentHeight < queryState.LastProcessedBlock {
		qe.logger.Warn("Chain appears to have been reset, resyncing from block 0",
			"indexer_height", currentHeight,
			"last_processed", queryState.LastProcessedBlock)
		queryState.LastProcessedBlock = 0
		queryState.LastProcessedTxIndex = 0
	}

	// Check if we've already processed up to the current height
	if queryState.LastProcessedBlock >= currentHeight {
		qe.logger.Debug("Already processed up to current block", "last_processed", queryState.LastProcessedBlock, "current", currentHeight)
		// Even if no new transactions, update to current height to keep queries efficient
		if queryState.LastProcessedBlock < currentHeight {
			queryState.LastProcessedBlock = currentHeight
			queryState.LastProcessedTxIndex = 0
		}
		return []any{}, nil
	}

	// Get processing position
	blockHeight, txIndex := queryState.GetProcessingPosition()

	// Query from last processed position to current block
	qe.logger.Debug("Querying user events", "from_block", blockHeight, "from_tx_index", txIndex, "to_block", currentHeight)

	// Log the query range that will be used
	if txIndex > 0 {
		qe.logger.Info("Executing UserEvents GraphQL query with block range",
			"query_type", "user_events",
			"block_range", fmt.Sprintf("(block > %d AND block < %d) OR (block = %d AND tx_index > %d)",
				blockHeight, currentHeight, blockHeight, txIndex))
	} else {
		qe.logger.Info("Executing UserEvents GraphQL query with block range",
			"query_type", "user_events",
			"block_range", fmt.Sprintf("(block > %d AND block < %d) OR (block = %d AND tx_index > 0)",
				blockHeight, currentHeight, blockHeight))
	}

	transactions, err := qe.queryClient.QueryUserEvents(ctx, blockHeight, txIndex, currentHeight)
	if err != nil {
		return nil, err
	}

	// Debug log all transactions found before filtering
	qe.logger.Debug("Raw transactions from GraphQL",
		"query_type", "user_events",
		"total_transactions", len(transactions),
		"block_range", fmt.Sprintf("%d-%d", blockHeight, currentHeight))

	for i, tx := range transactions {
		qe.logger.Debug("Transaction found",
			"index", i,
			"hash", tx.Hash,
			"block_height", tx.BlockHeight,
			"tx_index", tx.Index,
			"event_count", len(tx.Response.Events))
	}

	// Filter transactions to only include those up to current block height
	var filteredTransactions []graphql.Transaction
	for _, tx := range transactions {
		if tx.BlockHeight <= currentHeight {
			filteredTransactions = append(filteredTransactions, tx)
		}
	}

	qe.logger.Info("Filtered user events by current block height",
		"total_from_indexer", len(transactions),
		"filtered_valid", len(filteredTransactions),
		"current_height", currentHeight)

	// If no transactions found, advance to current height to keep queries efficient
	if len(filteredTransactions) == 0 && currentHeight > queryState.LastProcessedBlock {
		qe.logger.Debug("No transactions found, advancing to current height",
			"from", queryState.LastProcessedBlock,
			"to", currentHeight)
		queryState.LastProcessedBlock = currentHeight
		queryState.LastProcessedTxIndex = 0
	}

	// Convert to []any
	results := make([]any, len(filteredTransactions))
	for i, tx := range filteredTransactions {
		results[i] = tx
	}

	qe.logger.Debug("Retrieved user events", "count", len(results))
	return results, nil
}

// createUserEventsHandler creates a handler for user events (UserLinked and UserUnlinked)
func createUserEventsHandler(logger core.Logger, eventHandlers *EventHandlers) QueryHandler {
	return func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState) error {
		logger.Info("Processing user events query results", "guild_id", guild.GuildID, "results_count", len(results))

		// Convert results to transactions
		var transactions []graphql.Transaction
		for _, result := range results {
			if tx, ok := result.(graphql.Transaction); ok {
				transactions = append(transactions, tx)
			} else {
				logger.Error("Invalid result type, expected graphql.Transaction", "guild_id", guild.GuildID, "type", fmt.Sprintf("%T", result))
				continue
			}
		}

		// Process each transaction with incremental position updates
		for _, tx := range transactions {
			// Skip if we've already processed this transaction
			currentBlock, currentIndex := state.GetProcessingPosition()
			if tx.BlockHeight < currentBlock || (tx.BlockHeight == currentBlock && tx.Index <= currentIndex) {
				logger.Debug("Skipping already processed transaction",
					"tx_hash", tx.Hash,
					"tx_block", tx.BlockHeight,
					"tx_index", tx.Index,
					"current_block", currentBlock,
					"current_index", currentIndex)
				continue
			}

			logger.Info("Processing user event transaction",
				"guild_id", guild.GuildID,
				"hash", tx.Hash,
				"block_height", tx.BlockHeight,
				"tx_index", tx.Index)

			// Process transaction events
			for _, event := range tx.Response.Events {
				switch event.Type {
				case "UserLinked":
					logger.Info("Found UserLinked event", "guild_id", guild.GuildID, "tx_hash", tx.Hash)

					if userLinked, err := graphql.ParseUserLinkedEvent(event); err == nil {
						eventObj := Event{
							Type:            UserLinkedEvent,
							TransactionHash: tx.Hash,
							BlockHeight:     tx.BlockHeight,
							UserLinked:      userLinked,
						}

						if err := eventHandlers.HandleUserLinked(eventObj); err != nil {
							logger.Error("Failed to handle UserLinked event",
								"guild_id", guild.GuildID,
								"tx_hash", tx.Hash,
								"error", err)
							return err
						}
					} else {
						logger.Error("Failed to parse UserLinked event",
							"guild_id", guild.GuildID,
							"tx_hash", tx.Hash,
							"error", err)
					}

				case "UserUnlinked":
					logger.Info("Found UserUnlinked event", "guild_id", guild.GuildID, "tx_hash", tx.Hash)

					if userUnlinked, err := graphql.ParseUserUnlinkedEvent(event); err == nil {
						eventObj := Event{
							Type:            UserUnlinkedEvent,
							TransactionHash: tx.Hash,
							BlockHeight:     tx.BlockHeight,
							UserUnlinked:    userUnlinked,
						}

						if err := eventHandlers.HandleUserUnlinked(eventObj); err != nil {
							logger.Error("Failed to handle UserUnlinked event",
								"guild_id", guild.GuildID,
								"tx_hash", tx.Hash,
								"error", err)
							return err
						}
					} else {
						logger.Error("Failed to parse UserUnlinked event",
							"guild_id", guild.GuildID,
							"tx_hash", tx.Hash,
							"error", err)
					}
				}
			}

			// Update position after successfully processing the transaction
			state.UpdateProcessingPosition(tx.BlockHeight, tx.Index)
			logger.Debug("Updated processing position",
				"guild_id", guild.GuildID,
				"block_height", tx.BlockHeight,
				"tx_index", tx.Index)

			// Save state incrementally if callback is available
			if saveCallback, ok := ctx.Value(saveCallbackKey).(func() error); ok {
				if err := saveCallback(); err != nil {
					logger.Error("Failed to save state incrementally",
						"guild_id", guild.GuildID,
						"tx_hash", tx.Hash,
						"error", err)
					// Continue processing but return error to indicate partial failure
					return err
				}
				logger.Debug("State saved incrementally after transaction",
					"guild_id", guild.GuildID,
					"tx_hash", tx.Hash)
			}
		}

		return nil
	}
}

// executeRoleEventsQuery executes the role events query
func (qe *QueryExecutor) executeRoleEventsQuery(ctx context.Context, queryState *storage.GuildQueryState) ([]any, error) {
	// Get current block height from indexer
	currentHeight, err := qe.queryClient.QueryLatestBlockHeight(ctx)
	if err != nil {
		qe.logger.Error("Failed to get current block height from indexer", "error", err)
		return nil, fmt.Errorf("failed to get current block height from indexer: %w", err)
	}

	// Check if chain was reset - if indexer height < last processed, reset to 0
	if currentHeight < queryState.LastProcessedBlock {
		qe.logger.Warn("Chain appears to have been reset, resyncing from block 0",
			"indexer_height", currentHeight,
			"last_processed", queryState.LastProcessedBlock)
		queryState.LastProcessedBlock = 0
		queryState.LastProcessedTxIndex = 0
	}

	// Check if we've already processed up to the current height
	if queryState.LastProcessedBlock >= currentHeight {
		qe.logger.Debug("Already processed up to current block", "last_processed", queryState.LastProcessedBlock, "current", currentHeight)
		// Even if no new transactions, update to current height to keep queries efficient
		if queryState.LastProcessedBlock < currentHeight {
			queryState.LastProcessedBlock = currentHeight
			queryState.LastProcessedTxIndex = 0
		}
		return []any{}, nil
	}

	// Get processing position
	blockHeight, txIndex := queryState.GetProcessingPosition()

	// Query from last processed position to current block
	qe.logger.Debug("Querying role events", "from_block", blockHeight, "from_tx_index", txIndex, "to_block", currentHeight)

	// Log the query range that will be used
	if txIndex > 0 {
		qe.logger.Info("Executing RoleEvents GraphQL query with block range",
			"query_type", "role_events",
			"block_range", fmt.Sprintf("(block > %d AND block < %d) OR (block = %d AND tx_index > %d)",
				blockHeight, currentHeight, blockHeight, txIndex))
	} else {
		qe.logger.Info("Executing RoleEvents GraphQL query with block range",
			"query_type", "role_events",
			"block_range", fmt.Sprintf("(block > %d AND block < %d) OR (block = %d AND tx_index > 0)",
				blockHeight, currentHeight, blockHeight))
	}

	transactions, err := qe.queryClient.QueryRoleEvents(ctx, blockHeight, txIndex, currentHeight)
	if err != nil {
		return nil, err
	}

	// Filter transactions to only include those up to current block height
	var filteredTransactions []graphql.Transaction
	for _, tx := range transactions {
		if tx.BlockHeight <= currentHeight {
			filteredTransactions = append(filteredTransactions, tx)
		}
	}

	qe.logger.Info("Filtered role events by current block height",
		"total_from_indexer", len(transactions),
		"filtered_valid", len(filteredTransactions),
		"current_height", currentHeight)

	// If no transactions found, advance to current height to keep queries efficient
	if len(filteredTransactions) == 0 && currentHeight > queryState.LastProcessedBlock {
		qe.logger.Debug("No transactions found, advancing to current height",
			"from", queryState.LastProcessedBlock,
			"to", currentHeight)
		queryState.LastProcessedBlock = currentHeight
		queryState.LastProcessedTxIndex = 0
	}

	// Convert to []any
	results := make([]any, len(filteredTransactions))
	for i, tx := range filteredTransactions {
		results[i] = tx
	}

	qe.logger.Debug("Retrieved role events", "count", len(results))
	return results, nil
}

// executeVerifyMembersQuery executes the VerifyMembers query
func (qe *QueryExecutor) executeVerifyMembersQuery(_ context.Context, _ *storage.GuildQueryState) ([]any, error) {
	// This would implement the actual member verification logic
	// For now, return empty results
	return []any{}, nil
}

// createRoleEventsHandler creates a handler for role events (RoleLinked and RoleUnlinked)
func createRoleEventsHandler(logger core.Logger, eventHandlers *EventHandlers) QueryHandler {
	return func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState) error {
		logger.Info("Processing role events query results", "guild_id", guild.GuildID, "results_count", len(results))

		// Convert results to transactions
		var transactions []graphql.Transaction
		for _, result := range results {
			if tx, ok := result.(graphql.Transaction); ok {
				transactions = append(transactions, tx)
			} else {
				logger.Error("Invalid result type, expected graphql.Transaction", "guild_id", guild.GuildID, "type", fmt.Sprintf("%T", result))
				continue
			}
		}

		// Process each transaction with incremental position updates
		for _, tx := range transactions {
			// Skip if we've already processed this transaction
			currentBlock, currentIndex := state.GetProcessingPosition()
			if tx.BlockHeight < currentBlock || (tx.BlockHeight == currentBlock && tx.Index <= currentIndex) {
				logger.Debug("Skipping already processed transaction",
					"tx_hash", tx.Hash,
					"tx_block", tx.BlockHeight,
					"tx_index", tx.Index,
					"current_block", currentBlock,
					"current_index", currentIndex)
				continue
			}

			logger.Info("Processing role event transaction",
				"guild_id", guild.GuildID,
				"hash", tx.Hash,
				"block_height", tx.BlockHeight,
				"tx_index", tx.Index)

			// Process transaction events
			for _, event := range tx.Response.Events {
				switch event.Type {
				case "RoleLinked":
					logger.Info("Found RoleLinked event", "guild_id", guild.GuildID, "tx_hash", tx.Hash)

					if roleLinked, err := graphql.ParseRoleLinkedEvent(event); err == nil {
						// Only process if this event is for the current guild
						if roleLinked.DiscordGuildID == guild.GuildID {
							eventObj := Event{
								Type:            RoleLinkedEvent,
								TransactionHash: tx.Hash,
								BlockHeight:     tx.BlockHeight,
								RoleLinked:      roleLinked,
							}

							if err := eventHandlers.HandleRoleLinked(eventObj); err != nil {
								logger.Error("Failed to handle RoleLinked event",
									"guild_id", guild.GuildID,
									"tx_hash", tx.Hash,
									"error", err)
								return err
							}
						} else {
							logger.Debug("RoleLinked event not for this guild, skipping",
								"guild_id", guild.GuildID,
								"event_guild_id", roleLinked.DiscordGuildID)
						}
					} else {
						logger.Error("Failed to parse RoleLinked event",
							"guild_id", guild.GuildID,
							"tx_hash", tx.Hash,
							"error", err)
					}

				case "RoleUnlinked":
					logger.Info("Found RoleUnlinked event", "guild_id", guild.GuildID, "tx_hash", tx.Hash)

					if roleUnlinked, err := graphql.ParseRoleUnlinkedEvent(event); err == nil {
						// Only process if this event is for the current guild
						if roleUnlinked.DiscordGuildID == guild.GuildID {
							eventObj := Event{
								Type:            RoleUnlinkedEvent,
								TransactionHash: tx.Hash,
								BlockHeight:     tx.BlockHeight,
								RoleUnlinked:    roleUnlinked,
							}

							if err := eventHandlers.HandleRoleUnlinked(eventObj); err != nil {
								logger.Error("Failed to handle RoleUnlinked event",
									"guild_id", guild.GuildID,
									"tx_hash", tx.Hash,
									"error", err)
								return err
							}
						} else {
							logger.Debug("RoleUnlinked event not for this guild, skipping",
								"guild_id", guild.GuildID,
								"event_guild_id", roleUnlinked.DiscordGuildID)
						}
					} else {
						logger.Error("Failed to parse RoleUnlinked event",
							"guild_id", guild.GuildID,
							"tx_hash", tx.Hash,
							"error", err)
					}
				}
			}

			// Update position after successfully processing the transaction
			state.UpdateProcessingPosition(tx.BlockHeight, tx.Index)
			logger.Debug("Updated processing position",
				"guild_id", guild.GuildID,
				"block_height", tx.BlockHeight,
				"tx_index", tx.Index)

			// Save state incrementally if callback is available
			if saveCallback, ok := ctx.Value(saveCallbackKey).(func() error); ok {
				if err := saveCallback(); err != nil {
					logger.Error("Failed to save state incrementally",
						"guild_id", guild.GuildID,
						"tx_hash", tx.Hash,
						"error", err)
					// Continue processing but return error to indicate partial failure
					return err
				}
				logger.Debug("State saved incrementally after transaction",
					"guild_id", guild.GuildID,
					"tx_hash", tx.Hash)
			}
		}

		return nil
	}
}
