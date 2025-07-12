package discord

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/allinbits/labs/projects/gnolinker/core"
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
	logger               core.Logger
}

// NewBot creates a new Discord bot
func NewBot(config Config, 
	userFlow workflows.UserLinkingWorkflow,
	roleFlow workflows.RoleLinkingWorkflow,
	syncFlow workflows.SyncWorkflow,
	logger core.Logger) (*Bot, error) {
	
	// Create Discord session
	session, err := discordgo.New("Bot " + config.Token)
	if err != nil {
		return nil, fmt.Errorf("failed to create Discord session: %w", err)
	}
	
	// Create platform adapter
	platform := NewDiscordPlatform(session, config)
	
	// Create interaction handlers
	interactionHandlers := NewInteractionHandlers(userFlow, roleFlow, syncFlow, config, logger)
	
	bot := &Bot{
		session:             session,
		platform:            platform,
		interactionHandlers: interactionHandlers,
		config:              config,
		logger:              logger,
	}
	
	// Set up event handlers
	session.AddHandler(bot.onReady)
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
	b.logger.Info("Bot is ready! Logged in", "username", event.User.Username)
	
	// Cleanup old commands if requested
	if b.config.CleanupOldCommands {
		err := b.interactionHandlers.CleanupOldCommands(s, b.config.GuildID)
		if err != nil {
			b.logger.Error("Failed to cleanup old commands", "error", err)
		}
	}
	
	// Register slash commands
	err := b.interactionHandlers.RegisterSlashCommands(s, b.config.GuildID)
	if err != nil {
		b.logger.Error("Failed to register slash commands", "error", err)
	}
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