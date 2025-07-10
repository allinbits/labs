package main

import (
	"os"
	"testing"
)

func TestParseArgs(t *testing.T) {
	// Save original env var and restore after test
	originalEnv := os.Getenv("GNOQUERY_REMOTE")
	defer func() {
		if originalEnv == "" {
			os.Unsetenv("GNOQUERY_REMOTE")
		} else {
			os.Setenv("GNOQUERY_REMOTE", originalEnv)
		}
	}()

	tests := []struct {
		name         string
		args         []string
		envVar       string
		wantRemote   string
		wantRealm    string
		wantFunction string
		wantErr      bool
	}{
		{
			name:         "basic args with default remote",
			args:         []string{"gno.land/r/test", "GetInfo()"},
			wantRemote:   "tcp://0.0.0.0:26657",
			wantRealm:    "gno.land/r/test",
			wantFunction: "GetInfo()",
			wantErr:      false,
		},
		{
			name:         "args with explicit remote flag",
			args:         []string{"-remote", "tcp://localhost:26657", "gno.land/r/test", "GetInfo()"},
			wantRemote:   "tcp://localhost:26657",
			wantRealm:    "gno.land/r/test",
			wantFunction: "GetInfo()",
			wantErr:      false,
		},
		{
			name:         "args with environment variable",
			args:         []string{"gno.land/r/test", "GetInfo()"},
			envVar:       "tcp://env.example.com:26657",
			wantRemote:   "tcp://env.example.com:26657",
			wantRealm:    "gno.land/r/test",
			wantFunction: "GetInfo()",
			wantErr:      false,
		},
		// Note: We can't easily test missing/no arguments because parseArgs calls os.Exit(1)
		// instead of returning an error. This would require refactoring to make it testable.
		{
			name:    "invalid flag",
			args:    []string{"-invalid", "gno.land/r/test", "GetInfo()"},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set environment variable if specified
			if tt.envVar != "" {
				os.Setenv("GNOQUERY_REMOTE", tt.envVar)
			} else {
				os.Unsetenv("GNOQUERY_REMOTE")
			}

			remote, realm, function, err := parseArgs(tt.args)

			if (err != nil) != tt.wantErr {
				t.Errorf("parseArgs() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if remote != tt.wantRemote {
					t.Errorf("parseArgs() remote = %v, want %v", remote, tt.wantRemote)
				}
				if realm != tt.wantRealm {
					t.Errorf("parseArgs() realm = %v, want %v", realm, tt.wantRealm)
				}
				if function != tt.wantFunction {
					t.Errorf("parseArgs() function = %v, want %v", function, tt.wantFunction)
				}
			}
		})
	}
}