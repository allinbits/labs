package gnoquery

import (
	"errors"
	"testing"
)

func TestNewClient(t *testing.T) {
	client := NewClient("tcp://localhost:26657")
	if client == nil {
		t.Error("NewClient() returned nil client")
	}
	
	if _, ok := client.(*gnoClient); !ok {
		t.Error("NewClient() did not return a *gnoClient")
	}
}

// mockClient implements Client interface for testing
type mockClient struct {
	result string
	err    error
}

func (m *mockClient) Query(realmPath, functionCall string) (string, error) {
	return m.result, m.err
}

func TestClientQuery(t *testing.T) {
	tests := []struct {
		name         string
		realmPath    string
		functionCall string
		mockResult   string
		mockErr      error
		wantErr      bool
		wantResult   string
	}{
		{
			name:         "successful query",
			realmPath:    "gno.land/r/test",
			functionCall: "GetInfo()",
			mockResult:   "(true bool)",
			wantErr:      false,
			wantResult:   "(true bool)",
		},
		{
			name:         "query error",
			realmPath:    "gno.land/r/test",
			functionCall: "GetInfo()",
			mockErr:      errors.New("query failed"),
			wantErr:      true,
			wantResult:   "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create mock client
			mock := &mockClient{
				result: tt.mockResult,
				err:    tt.mockErr,
			}

			result, err := mock.Query(tt.realmPath, tt.functionCall)

			if (err != nil) != tt.wantErr {
				t.Errorf("Client.Query() error = %v, wantErr %v", err, tt.wantErr)
			}

			if result != tt.wantResult {
				t.Errorf("Client.Query() result = %q, want %q", result, tt.wantResult)
			}
		})
	}
}