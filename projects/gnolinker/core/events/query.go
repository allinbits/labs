package events

import (
	"context"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core/storage"
)

// QueryType defines the type of query
type QueryType string

const (
	// EventStreamQuery continuously monitors blockchain events
	EventStreamQuery QueryType = "event_stream"
	// PeriodicCheckQuery runs at regular intervals
	PeriodicCheckQuery QueryType = "periodic_check"
	// OnDemandQuery runs when triggered
	OnDemandQuery QueryType = "on_demand"
)

// SaveStateFunc is a callback to save guild configuration
type SaveStateFunc func(guild *storage.GuildConfig) error

// QueryHandler processes query results
type QueryHandler func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState) error

// QueryHandlerWithCallback processes query results with incremental saving support
type QueryHandlerWithCallback func(ctx context.Context, results []any, guild *storage.GuildConfig, state *storage.GuildQueryState, saveCallback func() error) error

// QueryDefinition defines a reusable query
type QueryDefinition struct {
	QueryID      string        `json:"query_id"`
	Name         string        `json:"name"`
	Description  string        `json:"description"`
	QueryType    QueryType     `json:"query_type"`
	GraphQLQuery string        `json:"graphql_query"`
	Interval     time.Duration `json:"interval"`
	Handler      QueryHandler  `json:"-"` // Not serialized
	Enabled      bool          `json:"enabled"`
}

// GuildQueryState is defined in storage/types.go

// QueryRegistry manages all registered queries
type QueryRegistry struct {
	queries map[string]*QueryDefinition
}

// NewQueryRegistry creates a new query registry
func NewQueryRegistry() *QueryRegistry {
	return &QueryRegistry{
		queries: make(map[string]*QueryDefinition),
	}
}

// RegisterQuery registers a new query definition
func (qr *QueryRegistry) RegisterQuery(def *QueryDefinition) {
	qr.queries[def.QueryID] = def
}

// GetQuery retrieves a query definition by ID
func (qr *QueryRegistry) GetQuery(queryID string) (*QueryDefinition, bool) {
	query, exists := qr.queries[queryID]
	return query, exists
}

// GetAllQueries returns all registered queries
func (qr *QueryRegistry) GetAllQueries() map[string]*QueryDefinition {
	// Return a copy to prevent external modification
	result := make(map[string]*QueryDefinition)
	for k, v := range qr.queries {
		result[k] = v
	}
	return result
}

// GetQueriesByType returns queries of a specific type
func (qr *QueryRegistry) GetQueriesByType(queryType QueryType) []*QueryDefinition {
	var result []*QueryDefinition
	for _, query := range qr.queries {
		if query.QueryType == queryType {
			result = append(result, query)
		}
	}
	return result
}

// All GuildQueryState methods are defined in storage/types.go