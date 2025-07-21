package platforms

import (
	"github.com/allinbits/labs/projects/gnolinker/core"
)

// Platform defines the minimal interface that chat platforms must implement
type Platform interface {
	// Identity management
	GetUserID(message Message) string
	SendDirectMessage(userID, content string) error

	// Role management
	HasRole(guildID, userID, roleID string) (bool, error)
	AddRole(guildID, userID, roleID string) error
	RemoveRole(guildID, userID, roleID string) error
	GetOrCreateRole(guildID, name string) (*core.PlatformRole, error)
	GetRoleByID(guildID, roleID string) (*core.PlatformRole, error)
}

// Message represents a platform-agnostic message
type Message interface {
	GetAuthorID() string
	GetContent() string
	GetChannelID() string
	IsDirectMessage() bool
}

// BotMode represents a platform-specific bot implementation
type BotMode interface {
	// Start initializes and runs the bot
	Start() error

	// Stop gracefully shuts down the bot
	Stop() error

	// GetPlatform returns the underlying platform adapter
	GetPlatform() Platform
}
