package discord

// Config holds Discord-specific configuration
type Config struct {
	// Token is the Discord bot token
	Token string
	
	// CleanupOldCommands removes all existing slash commands on startup
	CleanupOldCommands bool
	
	// Note: AdminRoleID and VerifiedAddressRoleID are now managed per-guild
	// by the ConfigManager and stored in guild-specific configurations
}