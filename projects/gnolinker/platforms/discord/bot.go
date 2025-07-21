package discord

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/events"
	"github.com/allinbits/labs/projects/gnolinker/core/graphql"
	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
	"github.com/bwmarrin/discordgo"
)

// Bot represents a Discord bot instance
type Bot struct {
	session               *discordgo.Session
	platform              platforms.Platform
	interactionHandlers   *InteractionHandlers
	config                Config
	configManager         *config.ConfigManager
	logger                core.Logger
	queryProcessorManager *events.QueryProcessorManager
	eventHandlers         *events.EventHandlers
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

	// Initialize event monitoring components
	var queryProcessorManager *events.QueryProcessorManager
	var eventHandlers *events.EventHandlers

	// Check if event monitoring should be enabled
	if config.GraphQLEndpoint != "" && config.EnableEventMonitoring {
		logger.Info("Initializing event monitoring", "graphql_endpoint", config.GraphQLEndpoint)

		// Create GraphQL client with default realm configuration
		// Note: These paths match the defaults in the queries
		realmConfig := graphql.RealmConfig{
			UserRealmPath: "gno.land/r/linker000/discord/user/v0",
			RoleRealmPath: "gno.land/r/linker000/discord/role/v0",
		}

		queryClient := graphql.NewQueryClient(config.GraphQLEndpoint, realmConfig)

		// Create event handlers with all required parameters
		eventHandlers = events.NewEventHandlers(platform, configManager, session, logger, userFlow, roleFlow)

		// Create query registry with event handlers
		queryRegistry := events.CreateCoreQueryRegistry(logger, eventHandlers)

		// Create query processor manager
		queryProcessorManager = events.NewQueryProcessorManager(queryRegistry, configManager.GetStore(), queryClient, logger)
	} else {
		logger.Info("Event monitoring disabled", "graphql_endpoint", config.GraphQLEndpoint, "enable_monitoring", config.EnableEventMonitoring)
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
	session.AddHandler(bot.onPresenceUpdate)

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

	// Start query processor manager if event monitoring is enabled
	if b.queryProcessorManager != nil {
		ctx := context.Background()
		if err := b.queryProcessorManager.Start(ctx); err != nil {
			b.logger.Error("Failed to start query processor manager", "error", err)
			return fmt.Errorf("failed to start query processor manager: %w", err)
		}
		b.logger.Info("Query processor manager started")
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

	// Stop query processor manager if it's running
	if b.queryProcessorManager != nil {
		if err := b.queryProcessorManager.Stop(); err != nil {
			b.logger.Error("Failed to stop query processor manager", "error", err)
			// Continue with Discord session close anyway
		} else {
			b.logger.Info("Query processor manager stopped")
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

		// Add guild to query processor manager if event monitoring is enabled
		if b.queryProcessorManager != nil {
			if err := b.queryProcessorManager.AddGuild(guild.ID); err != nil {
				// Don't log as error if guild already exists (happens during startup)
				if !strings.Contains(err.Error(), "already exists") {
					b.logger.Error("Failed to add guild to query processor manager", "guild_id", guild.ID, "error", err)
				} else {
					b.logger.Debug("Guild already exists in query processor manager", "guild_id", guild.ID)
				}
			} else {
				b.logger.Info("Added guild to query processor manager", "guild_id", guild.ID)
			}
		}
	}
}

func (b *Bot) onGuildCreate(s *discordgo.Session, event *discordgo.GuildCreate) {
	b.logger.Info("Bot joined new guild", "guild_name", event.Name, "guild_id", event.ID, "member_count", event.MemberCount)

	// Ensure guild configuration exists and is properly set up
	guildConfig, err := b.configManager.EnsureGuildConfig(s, event.ID)
	if err != nil {
		b.logger.Error("Failed to ensure guild config", "guild_id", event.ID, "error", err)
		// Continue anyway - we can still register commands
	} else {
		b.logger.Info("Guild configuration ensured",
			"guild_id", event.ID,
			"admin_role_id", guildConfig.AdminRoleID,
			"verified_role_id", guildConfig.VerifiedRoleID,
		)

		// Add guild to query processor manager if event monitoring is enabled
		if b.queryProcessorManager != nil {
			if err := b.queryProcessorManager.AddGuild(event.ID); err != nil {
				// Don't log as error if guild already exists (happens during startup)
				if !strings.Contains(err.Error(), "already exists") {
					b.logger.Error("Failed to add guild to query processor manager", "guild_id", event.ID, "error", err)
				} else {
					b.logger.Debug("Guild already exists in query processor manager", "guild_id", event.ID)
				}
			} else {
				b.logger.Info("Added guild to query processor manager", "guild_id", event.ID)
			}
		}
	}

	// Register slash commands for the new guild
	if err := b.interactionHandlers.RegisterSlashCommands(s, event.ID); err != nil {
		b.logger.Error("Failed to register commands for new guild", "guild_id", event.ID, "error", err)
		return
	}

	b.logger.Info("Successfully registered commands for new guild", "guild_id", event.ID)
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

func (b *Bot) onPresenceUpdate(s *discordgo.Session, p *discordgo.PresenceUpdate) {
	if b.eventHandlers == nil {
		return
	}

	guildID := p.GuildID
	userID := p.User.ID

	// Determine if user is online/active
	isActive := false
	switch p.Status {
	case discordgo.StatusOnline, discordgo.StatusIdle, discordgo.StatusDoNotDisturb:
		isActive = true
	case discordgo.StatusOffline, discordgo.StatusInvisible:
		isActive = false
	}

	b.logger.Debug("Presence update received",
		"guild_id", guildID,
		"user_id", userID,
		"status", p.Status,
		"is_active", isActive)

	if err := b.eventHandlers.UpdateUserPresence(guildID, userID, isActive); err != nil {
		b.logger.Error("Failed to update user presence",
			"guild_id", guildID,
			"user_id", userID,
			"error", err)
	}
}
