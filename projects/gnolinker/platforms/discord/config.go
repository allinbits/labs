package discord

// Config holds Discord-specific configuration
type Config struct {
	// Token is the Discord bot token
	Token string

	// CleanupOldCommands removes all existing slash commands on startup
	CleanupOldCommands bool

	// GraphQLEndpoint is the WebSocket endpoint for the tx-indexer GraphQL subscription
	GraphQLEndpoint string

	// EnableEventMonitoring enables real-time event monitoring via GraphQL subscriptions
	EnableEventMonitoring bool

	// Note: AdminRoleID and VerifiedAddressRoleID are now managed per-guild
	// by the ConfigManager and stored in guild-specific configurations
}
