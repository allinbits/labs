package storage

import (
	"encoding/json"
	"testing"
	"time"
)

func TestNewGuildConfig(t *testing.T) {
	t.Parallel()
	guildID := "123456789"
	config := NewGuildConfig(guildID)

	if config.GuildID != guildID {
		t.Errorf("NewGuildConfig() GuildID = %q, want %q", config.GuildID, guildID)
	}

	if config.Settings == nil {
		t.Error("NewGuildConfig() Settings map should be initialized")
	}

	if config.LastUpdated.IsZero() {
		t.Error("NewGuildConfig() LastUpdated should be set")
	}

	// Should be recent
	if time.Since(config.LastUpdated) > time.Second {
		t.Error("NewGuildConfig() LastUpdated should be recent")
	}
}

func TestGuildConfig_GetSetString(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name     string
		key      string
		setValue string
		setKey   string
		def      string
		want     string
	}{
		{
			name:     "existing key",
			key:      "test_key",
			setValue: "test_value",
			setKey:   "test_key",
			def:      "default",
			want:     "test_value",
		},
		{
			name:     "missing key returns default",
			key:      "missing_key",
			setValue: "",
			setKey:   "",
			def:      "default_value",
			want:     "default_value",
		},
		{
			name:     "empty string value",
			key:      "empty_key",
			setValue: "",
			setKey:   "empty_key",
			def:      "default",
			want:     "",
		},
		{
			name:     "empty default",
			key:      "missing",
			setValue: "",
			setKey:   "",
			def:      "",
			want:     "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			config := NewGuildConfig("12345")
			oldTime := config.LastUpdated

			if tt.setKey != "" {
				config.SetString(tt.setKey, tt.setValue)
				
				// Verify LastUpdated was modified
				if !config.LastUpdated.After(oldTime) {
					t.Error("SetString() should update LastUpdated timestamp")
				}
			}

			got := config.GetString(tt.key, tt.def)
			if got != tt.want {
				t.Errorf("GetString(%q, %q) = %q, want %q", tt.key, tt.def, got, tt.want)
			}
		})
	}
}

func TestGuildConfig_GetSetBool(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name     string
		key      string
		setValue bool
		setKey   string
		def      bool
		want     bool
	}{
		{
			name:     "existing true",
			key:      "test_bool",
			setValue: true,
			setKey:   "test_bool",
			def:      false,
			want:     true,
		},
		{
			name:     "existing false",
			key:      "test_bool",
			setValue: false,
			setKey:   "test_bool",
			def:      true,
			want:     false,
		},
		{
			name:     "missing key returns default true",
			key:      "missing",
			setValue: false,
			setKey:   "",
			def:      true,
			want:     true,
		},
		{
			name:     "missing key returns default false",
			key:      "missing",
			setValue: false,
			setKey:   "",
			def:      false,
			want:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			config := NewGuildConfig("12345")

			if tt.setKey != "" {
				config.SetBool(tt.setKey, tt.setValue)
			}

			got := config.GetBool(tt.key, tt.def)
			if got != tt.want {
				t.Errorf("GetBool(%q, %t) = %t, want %t", tt.key, tt.def, got, tt.want)
			}
		})
	}
}

func TestGuildConfig_GetSetInt(t *testing.T) {
	t.Parallel()
	tests := []struct{
		name     string
		key      string
		setValue int
		setKey   string
		def      int
		want     int
	}{
		{
			name:     "existing positive int",
			key:      "test_int",
			setValue: 42,
			setKey:   "test_int",
			def:      0,
			want:     42,
		},
		{
			name:     "existing zero",
			key:      "test_zero",
			setValue: 0,
			setKey:   "test_zero",
			def:      99,
			want:     0,
		},
		{
			name:     "existing negative int",
			key:      "test_negative",
			setValue: -123,
			setKey:   "test_negative",
			def:      0,
			want:     -123,
		},
		{
			name:     "missing key returns default",
			key:      "missing",
			setValue: 0,
			setKey:   "",
			def:      100,
			want:     100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			config := NewGuildConfig("12345")

			if tt.setKey != "" {
				config.SetInt(tt.setKey, tt.setValue)
			}

			got := config.GetInt(tt.key, tt.def)
			if got != tt.want {
				t.Errorf("GetInt(%q, %d) = %d, want %d", tt.key, tt.def, got, tt.want)
			}
		})
	}
}

func TestGuildConfig_GetSetDuration(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name     string
		key      string
		setValue time.Duration
		setKey   string
		def      time.Duration
		want     time.Duration
	}{
		{
			name:     "existing duration",
			key:      "test_duration",
			setValue: 5 * time.Minute,
			setKey:   "test_duration",
			def:      time.Second,
			want:     5 * time.Minute,
		},
		{
			name:     "zero duration",
			key:      "zero_duration",
			setValue: 0,
			setKey:   "zero_duration",
			def:      time.Hour,
			want:     0,
		},
		{
			name:     "missing key returns default",
			key:      "missing",
			setValue: 0,
			setKey:   "",
			def:      30 * time.Second,
			want:     30 * time.Second,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			config := NewGuildConfig("12345")

			if tt.setKey != "" {
				config.SetDuration(tt.setKey, tt.setValue)
			}

			got := config.GetDuration(tt.key, tt.def)
			if got != tt.want {
				t.Errorf("GetDuration(%q, %v) = %v, want %v", tt.key, tt.def, got, tt.want)
			}
		})
	}
}

func TestGuildConfig_HasAdminRole(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name        string
		adminRoleID string
		want        bool
	}{
		{
			name:        "has admin role",
			adminRoleID: "admin123",
			want:        true,
		},
		{
			name:        "no admin role - empty string",
			adminRoleID: "",
			want:        false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			config := NewGuildConfig("12345")
			config.AdminRoleID = tt.adminRoleID

			got := config.HasAdminRole()
			if got != tt.want {
				t.Errorf("HasAdminRole() = %t, want %t", got, tt.want)
			}
		})
	}
}

func TestGuildConfig_HasVerifiedRole(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name           string
		verifiedRoleID string
		want           bool
	}{
		{
			name:           "has verified role",
			verifiedRoleID: "verified456",
			want:           true,
		},
		{
			name:           "no verified role - empty string",
			verifiedRoleID: "",
			want:           false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			config := NewGuildConfig("12345")
			config.VerifiedRoleID = tt.verifiedRoleID

			got := config.HasVerifiedRole()
			if got != tt.want {
				t.Errorf("HasVerifiedRole() = %t, want %t", got, tt.want)
			}
		})
	}
}

func TestGuildConfig_JSONSerialization(t *testing.T) {
	t.Parallel()
	// Create a config with various data types
	original := NewGuildConfig("test-guild-123")
	original.AdminRoleID = "admin-role-456"
	original.VerifiedRoleID = "verified-role-789"
	original.SetString("string_key", "string_value")
	original.SetBool("bool_key", true)
	original.SetInt("int_key", 42)
	original.SetDuration("duration_key", 5*time.Minute)

	// Serialize to JSON
	data, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("json.Marshal() failed: %v", err)
	}

	// Deserialize from JSON
	var restored GuildConfig
	if err := json.Unmarshal(data, &restored); err != nil {
		t.Fatalf("json.Unmarshal() failed: %v", err)
	}

	// Verify core fields
	if restored.GuildID != original.GuildID {
		t.Errorf("GuildID = %q, want %q", restored.GuildID, original.GuildID)
	}
	if restored.AdminRoleID != original.AdminRoleID {
		t.Errorf("AdminRoleID = %q, want %q", restored.AdminRoleID, original.AdminRoleID)
	}
	if restored.VerifiedRoleID != original.VerifiedRoleID {
		t.Errorf("VerifiedRoleID = %q, want %q", restored.VerifiedRoleID, original.VerifiedRoleID)
	}

	// Verify settings map
	if restored.GetString("string_key", "") != "string_value" {
		t.Error("String setting not preserved after JSON round-trip")
	}
	if !restored.GetBool("bool_key", false) {
		t.Error("Bool setting not preserved after JSON round-trip")
	}
	if restored.GetInt("int_key", 0) != 42 {
		t.Error("Int setting not preserved after JSON round-trip")
	}
	if restored.GetDuration("duration_key", 0) != 5*time.Minute {
		t.Error("Duration setting not preserved after JSON round-trip")
	}

	// Verify LastUpdated is preserved
	if !restored.LastUpdated.Equal(original.LastUpdated) {
		t.Error("LastUpdated not preserved after JSON round-trip")
	}

	// Verify ETag is NOT serialized (should be empty)
	if restored.ETag != "" {
		t.Errorf("ETag should not be serialized, got %q", restored.ETag)
	}
}

func TestGuildConfig_BoolParsing(t *testing.T) {
	t.Parallel()

	// Test various bool string representations that strconv.ParseBool accepts
	validBoolValues := map[string]bool{
		"true":  true,
		"TRUE":  true,
		"True":  true,
		"1":     true,
		"false": false,
		"FALSE": false,
		"False": false,
		"0":     false,
	}

	for strVal, expectedBool := range validBoolValues {
		t.Run("parse_"+strVal, func(t *testing.T) {
			t.Parallel()
			// Create a new config instance for each subtest to avoid data races
			config := NewGuildConfig("12345")
			// Manually set the string value to test parsing
			config.Settings["test_bool"] = strVal

			got := config.GetBool("test_bool", !expectedBool) // Use opposite as default to ensure parsing works
			if got != expectedBool {
				t.Errorf("GetBool() with string %q = %t, want %t", strVal, got, expectedBool)
			}
		})
	}

	// Test invalid bool value falls back to default
	t.Run("invalid_bool_fallback", func(t *testing.T) {
		t.Parallel()
		// Create a new config instance for this subtest to avoid data races
		config := NewGuildConfig("12345")
		config.Settings["invalid_bool"] = "not_a_bool"
		got := config.GetBool("invalid_bool", true)
		if got != true {
			t.Error("GetBool() with invalid string should return default value")
		}
	})
}

func TestGuildConfig_IntParsing(t *testing.T) {
	t.Parallel()

	// Test various int string representations
	validIntValues := map[string]int{
		"42":   42,
		"-123": -123,
		"0":    0,
		"9999": 9999,
	}

	for strVal, expectedInt := range validIntValues {
		t.Run("parse_"+strVal, func(t *testing.T) {
			t.Parallel()
			// Create a new config instance for each subtest to avoid data races
			config := NewGuildConfig("12345")
			// Manually set the string value to test parsing
			config.Settings["test_int"] = strVal

			got := config.GetInt("test_int", 999) // Use different default to ensure parsing works
			if got != expectedInt {
				t.Errorf("GetInt() with string %q = %d, want %d", strVal, got, expectedInt)
			}
		})
	}

	// Test invalid int value falls back to default
	t.Run("invalid_int_fallback", func(t *testing.T) {
		t.Parallel()
		// Create a new config instance for this subtest to avoid data races
		config := NewGuildConfig("12345")
		config.Settings["invalid_int"] = "not_a_number"
		got := config.GetInt("invalid_int", 999)
		if got != 999 {
			t.Error("GetInt() with invalid string should return default value")
		}
	})
}