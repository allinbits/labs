package events

import (
	"testing"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/graphql"
)

func TestCreateCoreQueryRegistry(t *testing.T) {
	logger := core.NewSlogLogger(core.ParseLogLevel("info"))

	// Create a mock event handlers (nil is fine for this test)
	registry := CreateCoreQueryRegistry(logger, nil)

	if registry == nil {
		t.Fatal("CreateCoreQueryRegistry returned nil")
	}

	// Test that core queries are registered
	expectedQueries := []string{
		UserEventsQueryID,
		RoleEventsQueryID,
		VerifyHighPriorityQueryID,
		VerifyMediumPriorityQueryID,
		VerifyLowPriorityQueryID,
	}

	for _, queryID := range expectedQueries {
		query, exists := registry.GetQuery(queryID)
		if !exists {
			t.Errorf("Expected query %s to be registered", queryID)
			continue
		}

		if query.QueryID != queryID {
			t.Errorf("Expected query ID %s, got %s", queryID, query.QueryID)
		}

		if query.Name == "" {
			t.Errorf("Query %s should have a name", queryID)
		}

		if query.Description == "" {
			t.Errorf("Query %s should have a description", queryID)
		}

		if query.Interval <= 0 {
			t.Errorf("Query %s should have a positive interval", queryID)
		}

		if !query.Enabled {
			t.Errorf("Query %s should be enabled by default", queryID)
		}

		if query.Handler == nil {
			t.Errorf("Query %s should have a handler", queryID)
		}
	}
}

func TestQueryConstants(t *testing.T) {
	// Test that query constants are defined correctly
	if UserEventsQueryID != "user_events" {
		t.Errorf("Expected UserEventsQueryID to be 'user_events', got '%s'", UserEventsQueryID)
	}

	if RoleEventsQueryID != "role_events" {
		t.Errorf("Expected RoleEventsQueryID to be 'role_events', got '%s'", RoleEventsQueryID)
	}

	if VerifyHighPriorityQueryID != "verify_high_priority" {
		t.Errorf("Expected VerifyHighPriorityQueryID to be 'verify_high_priority', got '%s'", VerifyHighPriorityQueryID)
	}

	if VerifyMediumPriorityQueryID != "verify_medium_priority" {
		t.Errorf("Expected VerifyMediumPriorityQueryID to be 'verify_medium_priority', got '%s'", VerifyMediumPriorityQueryID)
	}

	if VerifyLowPriorityQueryID != "verify_low_priority" {
		t.Errorf("Expected VerifyLowPriorityQueryID to be 'verify_low_priority', got '%s'", VerifyLowPriorityQueryID)
	}
}

func TestQueryIntervals(t *testing.T) {
	logger := core.NewSlogLogger(core.ParseLogLevel("info"))
	registry := CreateCoreQueryRegistry(logger, nil)

	// Test user events interval (should be fast for event streaming)
	userQuery, exists := registry.GetQuery(UserEventsQueryID)
	if !exists {
		t.Fatal("User events query not found")
	}
	if userQuery.Interval != 5*time.Second {
		t.Errorf("Expected user events interval to be 5s, got %v", userQuery.Interval)
	}

	// Test role events interval (should be fast for event streaming)
	roleQuery, exists := registry.GetQuery(RoleEventsQueryID)
	if !exists {
		t.Fatal("Role events query not found")
	}
	if roleQuery.Interval != 5*time.Second {
		t.Errorf("Expected role events interval to be 5s, got %v", roleQuery.Interval)
	}

	// Test high priority verify interval (should be fastest)
	verifyHighQuery, exists := registry.GetQuery(VerifyHighPriorityQueryID)
	if !exists {
		t.Fatal("Verify high priority query not found")
	}
	if verifyHighQuery.Interval != 1*time.Minute {
		t.Errorf("Expected verify high priority interval to be 1m, got %v", verifyHighQuery.Interval)
	}

	// Test medium priority verify interval
	verifyMediumQuery, exists := registry.GetQuery(VerifyMediumPriorityQueryID)
	if !exists {
		t.Fatal("Verify medium priority query not found")
	}
	if verifyMediumQuery.Interval != 5*time.Minute {
		t.Errorf("Expected verify medium priority interval to be 5m, got %v", verifyMediumQuery.Interval)
	}

	// Test low priority verify interval (should be slowest)
	verifyLowQuery, exists := registry.GetQuery(VerifyLowPriorityQueryID)
	if !exists {
		t.Fatal("Verify low priority query not found")
	}
	if verifyLowQuery.Interval != 30*time.Minute {
		t.Errorf("Expected verify low priority interval to be 30m, got %v", verifyLowQuery.Interval)
	}
}

func TestQueryTypes(t *testing.T) {
	logger := core.NewSlogLogger(core.ParseLogLevel("info"))
	registry := CreateCoreQueryRegistry(logger, nil)

	// Test user events query type
	userQuery, exists := registry.GetQuery(UserEventsQueryID)
	if !exists {
		t.Fatal("User events query not found")
	}
	if userQuery.QueryType != EventStreamQuery {
		t.Errorf("Expected user events to be EventStreamQuery, got %s", userQuery.QueryType)
	}

	// Test role events query type
	roleQuery, exists := registry.GetQuery(RoleEventsQueryID)
	if !exists {
		t.Fatal("Role events query not found")
	}
	if roleQuery.QueryType != EventStreamQuery {
		t.Errorf("Expected role events to be EventStreamQuery, got %s", roleQuery.QueryType)
	}

	// Test verify query types - all should be periodic check
	verifyQueries := []string{
		VerifyHighPriorityQueryID,
		VerifyMediumPriorityQueryID,
		VerifyLowPriorityQueryID,
	}

	for _, queryID := range verifyQueries {
		verifyQuery, exists := registry.GetQuery(queryID)
		if !exists {
			t.Fatalf("Verify query %s not found", queryID)
		}
		if verifyQuery.QueryType != PeriodicCheckQuery {
			t.Errorf("Expected %s to be PeriodicCheckQuery, got %s", queryID, verifyQuery.QueryType)
		}
	}
}

func TestNewQueryExecutor(t *testing.T) {
	logger := core.NewSlogLogger(core.ParseLogLevel("info"))

	// Create a query client (doesn't need to be functional for this test)
	realmConfig := graphql.RealmConfig{
		UserRealmPath: "gno.land/r/test/user",
		RoleRealmPath: "gno.land/r/test/role",
	}
	queryClient := graphql.NewQueryClient("http://example.com", realmConfig)

	executor := NewQueryExecutor(queryClient, logger)

	if executor == nil {
		t.Fatal("NewQueryExecutor returned nil")
	}

	if executor.queryClient != queryClient {
		t.Error("Query client not set correctly")
	}

	if executor.logger != logger {
		t.Error("Logger not set correctly")
	}
}

func TestQueryTypeConstants(t *testing.T) {
	// Test query type constants
	if EventStreamQuery != "event_stream" {
		t.Errorf("Expected EventStreamQuery to be 'event_stream', got '%s'", EventStreamQuery)
	}

	if PeriodicCheckQuery != "periodic_check" {
		t.Errorf("Expected PeriodicCheckQuery to be 'periodic_check', got '%s'", PeriodicCheckQuery)
	}

	if OnDemandQuery != "on_demand" {
		t.Errorf("Expected OnDemandQuery to be 'on_demand', got '%s'", OnDemandQuery)
	}
}
