package discord

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/events"
	"github.com/allinbits/labs/projects/gnolinker/core/graphql"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
	"github.com/bwmarrin/discordgo"
)

// Bot represents a Discord bot instance
type Bot struct {
	session              *discordgo.Session
	platform             platforms.Platform
	interactionHandlers  *InteractionHandlers
	config               Config
	configManager        *config.ConfigManager
	logger               core.Logger
	queryProcessorManager *events.QueryProcessorManager
	eventHandlers        *events.EventHandlers
}

// NewBot creates a new Discord bot
func NewBot(config Config, 
	userFlow workflows.UserLinkingWorkflow,
	roleFlow workflows.RoleLinkingWorkflow,
	syncFlow workflows.SyncWorkflow,
	configManager *config.ConfigManager,
	logger core.Logger) (*Bot, error) {
	
	// Create Discord session
	session, err := discordgo.New("Bot " + config.Token)
	if err != nil {
		return nil, fmt.Errorf("failed to create Discord session: %w", err)
	}
	
	// Enable presence intents for activity tracking
	session.Identify.Intents = discordgo.IntentsGuilds | discordgo.IntentsGuildMembers | discordgo.IntentsGuildPresences
	
	// Create platform adapter with lock manager for safe role creation
	platform := NewDiscordPlatform(session, config, configManager.GetLockManager(), logger)
	
	// Create interaction handlers with config manager
	interactionHandlers := NewInteractionHandlers(userFlow, roleFlow, syncFlow, configManager, logger)
	
	// Create query processor manager and handlers if enabled
	var queryProcessorManager *events.QueryProcessorManager
	var eventHandlers *events.EventHandlers
	if config.EnableEventMonitoring && config.GraphQLEndpoint != "" {
		// Create GraphQL query client
		queryClient := graphql.NewQueryClient(config.GraphQLEndpoint)
		
		// Create event handlers
		eventHandlers = events.NewEventHandlers(platform, configManager, session, logger, userFlow, roleFlow)
		
		// Create query registry with core queries
		queryRegistry := events.CreateCoreQueryRegistry(logger, eventHandlers)
		
		// Create query processor manager
		queryProcessorManager = events.NewQueryProcessorManager(
			queryRegistry,
			configManager.GetStore(),
			queryClient,
			logger,
		)
		
		logger.Info("Created query-based event monitoring system")
	}
	
	bot := &Bot{
		session:               session,
		platform:              platform,
		interactionHandlers:   interactionHandlers,
		config:                config,
		configManager:         configManager,
		logger:                logger,
		queryProcessorManager: queryProcessorManager,
		eventHandlers:         eventHandlers,
	}
	
	// Set up event handlers
	session.AddHandler(bot.onReady)
	session.AddHandler(bot.onGuildCreate)
	session.AddHandler(bot.onMessageCreate)
	session.AddHandler(bot.interactionHandlers.HandleInteraction)
	
	// Add presence update handler for priority user tracking
	if bot.eventHandlers != nil {
		session.AddHandler(bot.onPresenceUpdate)
	}
	
	return bot, nil
}

// Start starts the Discord bot
func (b *Bot) Start() error {
	b.logger.Info("Starting Discord bot...")
	
	// Open connection
	err := b.session.Open()
	if err != nil {
		return fmt.Errorf("failed to open Discord connection: %w", err)
	}
	
	// Start query processor manager if enabled
	if b.queryProcessorManager != nil {
		ctx := context.Background()
		if err := b.queryProcessorManager.Start(ctx); err != nil {
			b.logger.Error("Failed to start query processor manager", "error", err)
			// Continue without event monitoring rather than failing completely
		} else {
			b.logger.Info("Query processor manager started successfully")
		}
	}
	
	b.logger.Info("Discord bot is running. Press Ctrl+C to exit.")
	
	// Wait for interrupt signal
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-stop
	
	return b.Stop()
}

// Stop stops the Discord bot
func (b *Bot) Stop() error {
	b.logger.Info("Stopping Discord bot...")
	
	// Stop query processor manager if running
	if b.queryProcessorManager != nil {
		if err := b.queryProcessorManager.Stop(); err != nil {
			b.logger.Error("Failed to stop query processor manager", "error", err)
		}
	}
	
	return b.session.Close()
}

// GetPlatform returns the platform adapter
func (b *Bot) GetPlatform() platforms.Platform {
	return b.platform
}

// Event handlers

func (b *Bot) onReady(s *discordgo.Session, event *discordgo.Ready) {
	if err := s.UpdateGameStatus(0, "Linking gno.land addresses"); err != nil {
		b.logger.Error("Failed to update game status", "error", err)
	}
	b.logger.Info("Bot is ready! Logged in", "username", event.User.Username, "guilds", len(event.Guilds))
	
	// Register commands for all existing guilds on startup
	for _, guild := range event.Guilds {
		b.logger.Info("Registering commands for guild", "guild_id", guild.ID)
		if err := b.interactionHandlers.RegisterSlashCommands(s, guild.ID); err != nil {
			b.logger.Error("Failed to register commands for guild", "guild_id", guild.ID, "error", err)
		}
		
		// Add guild to query processor manager if enabled
		if b.queryProcessorManager != nil {
			// Ensure guild configuration exists
			guildConfig, err := b.configManager.EnsureGuildConfig(s, guild.ID)
			if err != nil {
				b.logger.Error("Failed to ensure guild config for existing guild", "guild_id", guild.ID, "error", err)
				continue
			}
			
			// Initialize query states for existing guilds
			guildConfig.EnsureQueryState(events.UserEventsQueryID, true)
			guildConfig.EnsureQueryState(events.RoleEventsQueryID, true)
			guildConfig.EnsureQueryState(events.VerifyMembersQueryID, true) // Enabled by default for better UX
			
			// Save the updated config
			if err := b.configManager.UpdateGuildConfig(guild.ID, guildConfig); err != nil {
				b.logger.Error("Failed to save guild config with query states for existing guild", "guild_id", guild.ID, "error", err)
			}
			
			// Add guild to query processor manager
			if err := b.queryProcessorManager.AddGuild(guild.ID); err != nil {
				b.logger.Error("Failed to add existing guild to query processor manager", "guild_id", guild.ID, "error", err)
			} else {
				b.logger.Info("Added existing guild to query processor manager", "guild_id", guild.ID)
			}
		}
	}
}

func (b *Bot) onGuildCreate(s *discordgo.Session, event *discordgo.GuildCreate) {
	b.logger.Info("Bot joined new guild", "guild_name", event.Guild.Name, "guild_id", event.Guild.ID, "member_count", event.Guild.MemberCount)
	
	// Ensure guild configuration exists and is properly set up
	guildConfig, err := b.configManager.EnsureGuildConfig(s, event.Guild.ID)
	if err != nil {
		b.logger.Error("Failed to ensure guild config", "guild_id", event.Guild.ID, "error", err)
		// Continue anyway - we can still register commands
	} else {
		b.logger.Info("Guild configuration ensured", 
			"guild_id", event.Guild.ID,
			"admin_role_id", guildConfig.AdminRoleID,
			"verified_role_id", guildConfig.VerifiedRoleID,
		)
		
		// Add guild to query processor manager if enabled
		if b.queryProcessorManager != nil {
			// Initialize query states for the new guild
			guildConfig.EnsureQueryState(events.UserEventsQueryID, true)
			guildConfig.EnsureQueryState(events.RoleEventsQueryID, true)
			guildConfig.EnsureQueryState(events.VerifyMembersQueryID, true) // Enabled by default for better UX
			
			// Save the updated config
			if err := b.configManager.UpdateGuildConfig(event.Guild.ID, guildConfig); err != nil {
				b.logger.Error("Failed to save guild config with query states", "guild_id", event.Guild.ID, "error", err)
			}
			
			// Add guild to query processor manager
			if err := b.queryProcessorManager.AddGuild(event.Guild.ID); err != nil {
				b.logger.Error("Failed to add guild to query processor manager", "guild_id", event.Guild.ID, "error", err)
			} else {
				b.logger.Info("Added guild to query processor manager", "guild_id", event.Guild.ID)
			}
		}
	}
	
	// Register slash commands for the new guild
	if err := b.interactionHandlers.RegisterSlashCommands(s, event.Guild.ID); err != nil {
		b.logger.Error("Failed to register commands for new guild", "guild_id", event.Guild.ID, "error", err)
		return
	}
	
	b.logger.Info("Successfully registered commands for new guild", "guild_id", event.Guild.ID)
}

func (b *Bot) onMessageCreate(s *discordgo.Session, m *discordgo.MessageCreate) {
	// Ignore messages from the bot itself
	if m.Author.ID == s.State.User.ID {
		return
	}
	
	// Create message wrapper
	message := NewDiscordMessage(m)
	
	// Handle DMs with a simple redirect message
	if message.IsDirectMessage() {
		b.handleDirectMessage(s, m.Author.ID)
	}
}

func (b *Bot) handleDirectMessage(s *discordgo.Session, userID string) {
	response := "👋 Hi! I only work with slash commands in server channels now.\n\n" +
		"Please go to a server channel and use `/gnolinker help` to see all available commands.\n\n" +
		"All responses are private to you, so don't worry about spam!"
	
	// Send DM response
	channel, err := s.UserChannelCreate(userID)
	if err != nil {
		b.logger.Error("Failed to create DM channel", "error", err, "user_id", userID)
		return
	}
	
	_, err = s.ChannelMessageSend(channel.ID, response)
	if err != nil {
		b.logger.Error("Failed to send DM", "error", err, "user_id", userID)
	}
}

// onPresenceUpdate handles Discord presence updates for priority user tracking
func (b *Bot) onPresenceUpdate(s *discordgo.Session, event *discordgo.PresenceUpdate) {
	// Only process if we have event handlers and query processor manager
	if b.eventHandlers == nil || b.queryProcessorManager == nil {
		return
	}

	userID := event.User.ID
	status := event.Status
	guildID := event.GuildID

	b.logger.Debug("Presence update received", 
		"user_id", userID, 
		"status", status, 
		"guild_id", guildID,
	)

	// Update user priority based on presence status
	if err := b.updateUserPresencePriority(guildID, userID, status); err != nil {
		b.logger.Error("Failed to update user presence priority", 
			"guild_id", guildID,
			"user_id", userID,
			"status", status,
			"error", err,
		)
	}
}

// updateUserPresencePriority updates the priority queue based on user presence
func (b *Bot) updateUserPresencePriority(guildID, userID string, status discordgo.Status) error {
	// Get guild config to access query state
	config, err := b.configManager.GetGuildConfig(guildID)
	if err != nil {
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	// Get VerifyMembers query state
	verifyState, exists := config.GetQueryState(events.VerifyMembersQueryID)
	if !exists {
		// Query not enabled for this guild
		return nil
	}

	// Get current presence priority state
	presencePriority := b.getPresencePriorityState(verifyState)

	// Update priority based on status
	switch status {
	case discordgo.StatusOnline, discordgo.StatusDoNotDisturb:
		// High priority for active users
		b.addToPresencePriority(presencePriority, "high", userID)
		b.removeFromPresencePriority(presencePriority, "medium", userID)
		b.removeFromPresencePriority(presencePriority, "low", userID)
		
	case discordgo.StatusIdle:
		// Medium priority for idle users (if not already high priority)
		if !b.isInPresencePriority(presencePriority, "high", userID) {
			b.addToPresencePriority(presencePriority, "medium", userID)
			b.removeFromPresencePriority(presencePriority, "low", userID)
		}
		
	case discordgo.StatusOffline:
		// Move to low priority after a delay
		b.removeFromPresencePriority(presencePriority, "high", userID)
		// Keep in medium for 30 minutes, then move to low
		if !b.isInPresencePriority(presencePriority, "medium", userID) {
			b.addToPresencePriority(presencePriority, "low", userID)
		}
	}

	// Save updated state
	b.setPresencePriorityState(verifyState, presencePriority)
	
	// Update guild config
	return b.configManager.UpdateGuildConfig(guildID, config)
}

// Helper methods for presence priority management
func (b *Bot) getPresencePriorityState(queryState *storage.GuildQueryState) map[string][]string {
	if state, exists := queryState.GetState("presence_priority"); exists {
		if priorityMap, ok := state.(map[string]interface{}); ok {
			result := make(map[string][]string)
			for level, users := range priorityMap {
				if userList, ok := users.([]interface{}); ok {
					strList := make([]string, 0, len(userList))
					for _, user := range userList {
						if userStr, ok := user.(string); ok {
							strList = append(strList, userStr)
						}
					}
					result[level] = strList
				}
			}
			return result
		}
	}
	
	// Return default empty state
	return map[string][]string{
		"high":   []string{},
		"medium": []string{},
		"low":    []string{},
	}
}

func (b *Bot) setPresencePriorityState(queryState *storage.GuildQueryState, priority map[string][]string) {
	queryState.SetState("presence_priority", priority)
}

func (b *Bot) addToPresencePriority(priority map[string][]string, level, userID string) {
	users := priority[level]
	// Check if user is already in this level
	for _, existingUser := range users {
		if existingUser == userID {
			return // Already present
		}
	}
	priority[level] = append(users, userID)
}

func (b *Bot) removeFromPresencePriority(priority map[string][]string, level, userID string) {
	users := priority[level]
	for i, existingUser := range users {
		if existingUser == userID {
			// Remove user from slice
			priority[level] = append(users[:i], users[i+1:]...)
			return
		}
	}
}

func (b *Bot) isInPresencePriority(priority map[string][]string, level, userID string) bool {
	users := priority[level]
	for _, existingUser := range users {
		if existingUser == userID {
			return true
		}
	}
	return false
}