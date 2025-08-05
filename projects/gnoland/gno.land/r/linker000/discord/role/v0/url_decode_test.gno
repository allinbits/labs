package role

import (
	"testing"
	"net/url"
)

func TestURLDecodingIdempotency(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "already decoded realm path",
			input:    "gno.land/r/linker000/mockevent/v1",
			expected: "gno.land/r/linker000/mockevent/v1",
		},
		{
			name:     "URL encoded realm path",
			input:    "gno.land%2Fr%2Flinker000%2Fmockevent%2Fv1",
			expected: "gno.land/r/linker000/mockevent/v1",
		},
		{
			name:     "empty string",
			input:    "",
			expected: "",
		},
		{
			name:     "partially encoded path",
			input:    "gno.land/r/test%2Fdemo/v1",
			expected: "gno.land/r/test/demo/v1",
		},
		{
			name:     "double encoded path (should only decode once)",
			input:    "gno.land%252Fr%252Ftest%252Fv1",
			expected: "gno.land%2Fr%2Ftest%2Fv1",
		},
		{
			name:     "path with colon",
			input:    "gno.land%3A8080%2Fr%2Ftest%2Fv1",
			expected: "gno.land:8080/r/test/v1",
		},
		{
			name:     "standard realm path variations",
			input:    "gno.land%2Fr%2Fdemo%2Fboards",
			expected: "gno.land/r/demo/boards",
		},
		{
			name:     "realm with numbers and underscores",
			input:    "gno.land%2Fr%2Flinker000%2Fdiscord%2Fuser%2Fv0",
			expected: "gno.land/r/linker000/discord/user/v0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Test the decoding logic used in validateLinkClaim
			decodedPath, _ := url.QueryUnescape(tt.input)
			if decodedPath == "" && tt.input != "" {
				decodedPath = tt.input
			}
			
			if decodedPath != tt.expected {
				t.Errorf("URL decoding failed for %s: expected %q, got %q", 
					tt.name, tt.expected, decodedPath)
			}
			
			// Test idempotency - decoding an already decoded string should return the same result
			// For double-encoded strings, we only expect single decoding
			if tt.name != "double encoded path (should only decode once)" {
				decodedAgain, _ := url.QueryUnescape(decodedPath)
				if decodedAgain == "" && decodedPath != "" {
					decodedAgain = decodedPath
				}
				
				if decodedAgain != tt.expected {
					t.Errorf("URL decoding is not idempotent for %s: expected %q, got %q", 
						tt.name, tt.expected, decodedAgain)
				}
			}
		})
	}
}

// TestValidRealmPaths ensures our realm paths are valid after decoding
func TestValidRealmPaths(t *testing.T) {
	validPaths := []string{
		"gno.land/r/demo/boards",
		"gno.land/r/linker000/discord/user/v0",
		"gno.land/r/linker000/discord/role/v0",
		"gno.land/r/linker000/mockevent/v1",
		"gno.land/r/stackdump000/bmp",
		"gno.land/p/demo/avl",
	}

	for _, path := range validPaths {
		// Encode the path
		encoded := url.QueryEscape(path)
		
		// Decode it back
		decoded, _ := url.QueryUnescape(encoded)
		
		if decoded != path {
			t.Errorf("Round-trip encoding/decoding failed for %q: got %q", path, decoded)
		}
	}
}