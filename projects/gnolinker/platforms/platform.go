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
	HasRole(userID, roleID string) (bool, error)
	AddRole(userID, roleID string) error
	RemoveRole(userID, roleID string) error
	GetOrCreateRole(name string) (*core.PlatformRole, error)
	GetRoleByID(roleID string) (*core.PlatformRole, error)
	
	// Server management
	GetServerID() string
	IsAdmin(userID string) (bool, error)
}

// Message represents a platform-agnostic message
type Message interface {
	GetAuthorID() string
	GetContent() string
	GetChannelID() string
	IsDirectMessage() bool
}

// Command represents a parsed command
type Command struct {
	Name string
	Args []string
}

// CommandHandler handles platform-agnostic commands
type CommandHandler interface {
	HandleCommand(platform Platform, message Message, command Command) error
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