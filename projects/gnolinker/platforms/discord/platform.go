package discord

import (
	"fmt"
	"slices"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/lock"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
	"github.com/bwmarrin/discordgo"
)

// DiscordPlatform implements the Platform interface for Discord
type DiscordPlatform struct {
	session     *discordgo.Session
	config      Config
	roleManager *RoleManager
}

// NewDiscordPlatform creates a new Discord platform adapter
func NewDiscordPlatform(session *discordgo.Session, config Config, lockManager lock.LockManager, logger core.Logger) platforms.Platform {
	return &DiscordPlatform{
		session:     session,
		config:      config,
		roleManager: NewRoleManager(session, lockManager, logger),
	}
}

// GetUserID returns the user ID from a message
func (p *DiscordPlatform) GetUserID(message platforms.Message) string {
	return message.GetAuthorID()
}

// SendDirectMessage sends a direct message to a user
func (p *DiscordPlatform) SendDirectMessage(userID, content string) error {
	channel, err := p.session.UserChannelCreate(userID)
	if err != nil {
		return fmt.Errorf("failed to create DM channel: %w", err)
	}

	_, err = p.session.ChannelMessageSend(channel.ID, content)
	if err != nil {
		return fmt.Errorf("failed to send DM: %w", err)
	}

	return nil
}

// HasRole checks if a user has a specific role
func (p *DiscordPlatform) HasRole(guildID, userID, roleID string) (bool, error) {
	member, err := p.session.GuildMember(guildID, userID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild member: %w", err)
	}

	return slices.Contains(member.Roles, roleID), nil
}

// AddRole adds a role to a user
func (p *DiscordPlatform) AddRole(guildID, userID, roleID string) error {
	err := p.session.GuildMemberRoleAdd(guildID, userID, roleID)
	if err != nil {
		return fmt.Errorf("failed to add role: %w", err)
	}
	return nil
}

// RemoveRole removes a role from a user
func (p *DiscordPlatform) RemoveRole(guildID, userID, roleID string) error {
	err := p.session.GuildMemberRoleRemove(guildID, userID, roleID)
	if err != nil {
		return fmt.Errorf("failed to remove role: %w", err)
	}
	return nil
}

// GetOrCreateRole gets an existing role or creates a new one using distributed locking
func (p *DiscordPlatform) GetOrCreateRole(guildID, name string) (*core.PlatformRole, error) {
	return p.roleManager.GetOrCreateRole(guildID, name, nil)
}

// GetRoleByID retrieves a role by its ID
func (p *DiscordPlatform) GetRoleByID(guildID, roleID string) (*core.PlatformRole, error) {
	roles, err := p.session.GuildRoles(guildID)
	if err != nil {
		return nil, fmt.Errorf("failed to get guild roles: %w", err)
	}

	for _, role := range roles {
		if role.ID == roleID {
			return &core.PlatformRole{
				ID:   role.ID,
				Name: role.Name,
			}, nil
		}
	}

	return nil, fmt.Errorf("role not found: %s", roleID)
}

// IsAdmin checks if a user is an admin (has the admin role)
// DEPRECATED: Use ConfigManager.EnsureGuildConfig() and check AdminRoleID dynamically
func (p *DiscordPlatform) IsAdmin(guildID, userID string) (bool, error) {
	// This method is deprecated - admin roles are now managed per-guild
	// For backward compatibility, return false
	return false, nil
}

// Discord-specific methods for the verified address role

// AddVerifiedRole adds the verified address role to a user
// DEPRECATED: Use ConfigManager.EnsureGuildConfig() and manage VerifiedRoleID dynamically
func (p *DiscordPlatform) AddVerifiedRole(guildID, userID string) error {
	// This method is deprecated - verified roles are now managed per-guild
	return nil
}

// RemoveVerifiedRole removes the verified address role from a user
// DEPRECATED: Use ConfigManager.EnsureGuildConfig() and manage VerifiedRoleID dynamically
func (p *DiscordPlatform) RemoveVerifiedRole(guildID, userID string) error {
	// This method is deprecated - verified roles are now managed per-guild
	return nil
}
