package discord

// Config holds Discord-specific configuration
type Config struct {
	// Token is the Discord bot token
	Token string
	
	// AdminRoleID is the role that can manage realm-role links
	AdminRoleID string
	
	// VerifiedAddressRoleID is given to users who have linked their address
	VerifiedAddressRoleID string
	
	// CleanupOldCommands removes all existing slash commands on startup
	CleanupOldCommands bool
}