package platforms

import (
	"strings"
)

// ParseCommand parses a message content into a Command
func ParseCommand(content string) (*Command, bool) {
	parts := strings.Split(content, " ")
	if len(parts) == 0 || !strings.HasPrefix(parts[0], "!") {
		return nil, false
	}
	
	args := make([]string, 0)
	if len(parts) > 1 {
		args = parts[1:]
	}
	
	return &Command{
		Name: parts[0],
		Args: args,
	}, true
}

// CommandRouter routes commands to appropriate handlers
type CommandRouter struct {
	handlers map[string]CommandHandler
}

// NewCommandRouter creates a new command router
func NewCommandRouter() *CommandRouter {
	return &CommandRouter{
		handlers: make(map[string]CommandHandler),
	}
}

// RegisterHandler registers a command handler
func (r *CommandRouter) RegisterHandler(command string, handler CommandHandler) {
	r.handlers[command] = handler
}

// HandleCommand routes a command to the appropriate handler
func (r *CommandRouter) HandleCommand(platform Platform, message Message, command Command) error {
	handler, exists := r.handlers[command.Name]
	if !exists {
		return platform.SendDirectMessage(message.GetAuthorID(), 
			"Unknown command. Try `!help` to see available commands.")
	}
	
	return handler.HandleCommand(platform, message, command)
}