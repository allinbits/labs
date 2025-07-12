package discord

import "github.com/bwmarrin/discordgo"

// DiscordMessage wraps a discordgo.MessageCreate to implement the Message interface
type DiscordMessage struct {
	msg *discordgo.MessageCreate
}

// NewDiscordMessage creates a new DiscordMessage wrapper
func NewDiscordMessage(msg *discordgo.MessageCreate) *DiscordMessage {
	return &DiscordMessage{msg: msg}
}

// GetAuthorID returns the Discord user ID of the message author
func (m *DiscordMessage) GetAuthorID() string {
	return m.msg.Author.ID
}

// GetContent returns the message content
func (m *DiscordMessage) GetContent() string {
	return m.msg.Content
}

// GetChannelID returns the channel ID where the message was sent
func (m *DiscordMessage) GetChannelID() string {
	return m.msg.ChannelID
}

// IsDirectMessage returns true if the message is a direct message
func (m *DiscordMessage) IsDirectMessage() bool {
	return m.msg.GuildID == ""
}