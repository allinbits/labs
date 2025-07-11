package discord

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
	"github.com/bwmarrin/discordgo"
)

// Bot represents a Discord bot instance
type Bot struct {
	session    *discordgo.Session
	platform   platforms.Platform
	router     *platforms.CommandRouter
	config     Config
}

// NewBot creates a new Discord bot
func NewBot(config Config, 
	userFlow workflows.UserLinkingWorkflow,
	roleFlow workflows.RoleLinkingWorkflow,
	syncFlow workflows.SyncWorkflow) (*Bot, error) {
	
	// Create Discord session
	session, err := discordgo.New("Bot " + config.Token)
	if err != nil {
		return nil, fmt.Errorf("failed to create Discord session: %w", err)
	}
	
	// Create platform adapter
	platform := NewDiscordPlatform(session, config)
	
	// Create command handlers
	handlers := NewCommandHandlers(userFlow, roleFlow, syncFlow)
	
	// Create command router
	router := platforms.NewCommandRouter()
	router.RegisterHandler("!link", NewLinkHandler(handlers))
	router.RegisterHandler("!verify", NewVerifyHandler(handlers))
	router.RegisterHandler("!sync", NewSyncHandler(handlers))
	router.RegisterHandler("!help", NewHelpHandler())
	
	bot := &Bot{
		session:  session,
		platform: platform,
		router:   router,
		config:   config,
	}
	
	// Set up event handlers
	session.AddHandler(bot.onReady)
	session.AddHandler(bot.onMessageCreate)
	
	return bot, nil
}

// Start starts the Discord bot
func (b *Bot) Start() error {
	log.Println("Starting Discord bot...")
	
	// Open connection
	err := b.session.Open()
	if err != nil {
		return fmt.Errorf("failed to open Discord connection: %w", err)
	}
	
	log.Println("Discord bot is running. Press Ctrl+C to exit.")
	
	// Wait for interrupt signal
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-stop
	
	return b.Stop()
}

// Stop stops the Discord bot
func (b *Bot) Stop() error {
	log.Println("Stopping Discord bot...")
	return b.session.Close()
}

// GetPlatform returns the platform adapter
func (b *Bot) GetPlatform() platforms.Platform {
	return b.platform
}

// Event handlers

func (b *Bot) onReady(s *discordgo.Session, event *discordgo.Ready) {
	s.UpdateGameStatus(0, "Linking gno.land addresses")
	log.Printf("Bot is ready! Logged in as %s", event.User.Username)
}

func (b *Bot) onMessageCreate(s *discordgo.Session, m *discordgo.MessageCreate) {
	// Ignore messages from the bot itself
	if m.Author.ID == s.State.User.ID {
		return
	}
	
	// Create message wrapper
	message := NewDiscordMessage(m)
	
	// Handle DMs
	if message.IsDirectMessage() {
		b.handleDirectMessage(message)
		return
	}
	
	// Handle guild messages with !link
	if m.Content == "!link" {
		s.ChannelMessageSend(m.ChannelID, "Please DM me to start the linking process.")
	}
}

func (b *Bot) handleDirectMessage(message *DiscordMessage) {
	// Parse command
	command, isCommand := platforms.ParseCommand(message.GetContent())
	if !isCommand {
		b.platform.SendDirectMessage(message.GetAuthorID(), 
			"I'm not sure what you mean. Try `!help` to see available commands.")
		return
	}
	
	// Route command
	err := b.router.HandleCommand(b.platform, message, *command)
	if err != nil {
		log.Printf("Command handling error: %v", err)
		b.platform.SendDirectMessage(message.GetAuthorID(), 
			"Something went wrong processing your command. Please try again.")
	}
}