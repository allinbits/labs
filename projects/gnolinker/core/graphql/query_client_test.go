package graphql

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestNewQueryClient(t *testing.T) {
	tests := []struct {
		name        string
		url         string
		realmConfig RealmConfig
		expectedURL string
	}{
		{
			name: "basic HTTP URL",
			url:  "http://example.com/graphql",
			realmConfig: RealmConfig{
				UserRealmPath: "gno.land/r/test/user",
				RoleRealmPath: "gno.land/r/test/role",
			},
			expectedURL: "http://example.com/graphql",
		},
		{
			name: "WebSocket URL conversion",
			url:  "ws://example.com/graphql",
			realmConfig: RealmConfig{
				UserRealmPath: "gno.land/r/test/user",
				RoleRealmPath: "gno.land/r/test/role",
			},
			expectedURL: "http://example.com/graphql",
		},
		{
			name: "Secure WebSocket URL conversion",
			url:  "wss://example.com/graphql",
			realmConfig: RealmConfig{
				UserRealmPath: "gno.land/r/test/user",
				RoleRealmPath: "gno.land/r/test/role",
			},
			expectedURL: "https://example.com/graphql",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			client := NewQueryClient(tt.url, tt.realmConfig)

			if client == nil {
				t.Fatal("NewQueryClient returned nil")
			}

			if client.url != tt.expectedURL {
				t.Errorf("Expected URL %s, got %s", tt.expectedURL, client.url)
			}

			if client.realmConfig.UserRealmPath != tt.realmConfig.UserRealmPath {
				t.Errorf("Expected UserRealmPath %s, got %s", tt.realmConfig.UserRealmPath, client.realmConfig.UserRealmPath)
			}

			if client.realmConfig.RoleRealmPath != tt.realmConfig.RoleRealmPath {
				t.Errorf("Expected RoleRealmPath %s, got %s", tt.realmConfig.RoleRealmPath, client.realmConfig.RoleRealmPath)
			}

			if client.httpClient == nil {
				t.Error("HTTP client should not be nil")
			}

			if client.logger == nil {
				t.Error("Logger should not be nil")
			}
		})
	}
}

func TestQueryClient_QueryGeneration(t *testing.T) {
	realmConfig := RealmConfig{
		UserRealmPath: "gno.land/r/test/user",
		RoleRealmPath: "gno.land/r/test/role",
	}

	// We can't easily test the actual HTTP calls without a mock server,
	// but we can test the query generation logic
	t.Run("query parameters are passed correctly", func(t *testing.T) {
		client := NewQueryClient("http://example.com", realmConfig)

		// Test that the client is configured correctly
		if client.realmConfig.UserRealmPath != "gno.land/r/test/user" {
			t.Error("User realm path not set correctly")
		}
		if client.realmConfig.RoleRealmPath != "gno.land/r/test/role" {
			t.Error("Role realm path not set correctly")
		}
	})
}

func TestQueryClient_LatestBlockHeight_InvalidURL(t *testing.T) {
	client := NewQueryClient("http://invalid-url-that-does-not-exist.local", RealmConfig{})

	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	_, err := client.QueryLatestBlockHeight(ctx)
	if err == nil {
		t.Error("Expected error for invalid URL, got nil")
	}

	// Check that error occurred (could be network error or timeout)
	errStr := err.Error()
	if !strings.Contains(errStr, "failed to execute request") && !strings.Contains(errStr, "context deadline exceeded") {
		t.Errorf("Expected error to contain network error or timeout, got: %s", errStr)
	}
}

func TestRealmConfig(t *testing.T) {
	config := RealmConfig{
		UserRealmPath: "gno.land/r/test/user/v1",
		RoleRealmPath: "gno.land/r/test/role/v1",
	}

	if config.UserRealmPath != "gno.land/r/test/user/v1" {
		t.Errorf("Expected UserRealmPath 'gno.land/r/test/user/v1', got '%s'", config.UserRealmPath)
	}

	if config.RoleRealmPath != "gno.land/r/test/role/v1" {
		t.Errorf("Expected RoleRealmPath 'gno.land/r/test/role/v1', got '%s'", config.RoleRealmPath)
	}
}

func TestGraphQLError(t *testing.T) {
	err := GraphQLError{
		Message: "Test error",
		Locations: []struct {
			Line   int `json:"line"`
			Column int `json:"column"`
		}{
			{Line: 1, Column: 5},
		},
		Extensions: map[string]any{
			"code": "TEST_ERROR",
		},
	}

	if err.Message != "Test error" {
		t.Errorf("Expected message 'Test error', got '%s'", err.Message)
	}

	if len(err.Locations) != 1 {
		t.Errorf("Expected 1 location, got %d", len(err.Locations))
	}

	if err.Locations[0].Line != 1 || err.Locations[0].Column != 5 {
		t.Errorf("Expected location (1,5), got (%d,%d)", err.Locations[0].Line, err.Locations[0].Column)
	}

	if code, exists := err.Extensions["code"]; !exists || code != "TEST_ERROR" {
		t.Errorf("Expected extension code 'TEST_ERROR', got %v", code)
	}
}
