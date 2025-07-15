package discord

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
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
	
	// Create platform adapter with lock manager for safe role creation
	platform := NewDiscordPlatform(session, config, configManager.GetLockManager(), logger)
	
	// Create interaction handlers with config manager
	interactionHandlers := NewInteractionHandlers(userFlow, roleFlow, syncFlow, configManager, logger)
	
	bot := &Bot{
		session:             session,
		platform:            platform,
		interactionHandlers: interactionHandlers,
		config:              config,
		configManager:       configManager,
		logger:              logger,
	}
	
	// Set up event handlers
	session.AddHandler(bot.onReady)
	session.AddHandler(bot.onGuildCreate)
	session.AddHandler(bot.onMessageCreate)
	session.AddHandler(bot.interactionHandlers.HandleInteraction)
	
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
	return b.session.Close()
}

// GetPlatform returns the platform adapter
func (b *Bot) GetPlatform() platforms.Platform {
	return b.platform
}

// Event handlers

func (b *Bot) onReady(s *discordgo.Session, event *discordgo.Ready) {
	s.UpdateGameStatus(0, "Linking gno.land addresses")
	b.logger.Info("Bot is ready! Logged in", "username", event.User.Username, "guilds", len(event.Guilds))
	
	// Register commands for all existing guilds on startup
	for _, guild := range event.Guilds {
		b.logger.Info("Registering commands for guild", "guild_id", guild.ID)
		if err := b.interactionHandlers.RegisterSlashCommands(s, guild.ID); err != nil {
			b.logger.Error("Failed to register commands for guild", "guild_id", guild.ID, "error", err)
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