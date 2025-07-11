package discord

import (
	"errors"
	"fmt"
	"slices"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
	"github.com/bwmarrin/discordgo"
)

// DiscordPlatform implements the Platform interface for Discord
type DiscordPlatform struct {
	session *discordgo.Session
	config  Config
}

// NewDiscordPlatform creates a new Discord platform adapter
func NewDiscordPlatform(session *discordgo.Session, config Config) platforms.Platform {
	return &DiscordPlatform{
		session: session,
		config:  config,
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
func (p *DiscordPlatform) HasRole(userID, roleID string) (bool, error) {
	member, err := p.session.GuildMember(p.config.GuildID, userID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild member: %w", err)
	}
	
	return slices.Contains(member.Roles, roleID), nil
}

// AddRole adds a role to a user
func (p *DiscordPlatform) AddRole(userID, roleID string) error {
	err := p.session.GuildMemberRoleAdd(p.config.GuildID, userID, roleID)
	if err != nil {
		return fmt.Errorf("failed to add role: %w", err)
	}
	return nil
}

// RemoveRole removes a role from a user
func (p *DiscordPlatform) RemoveRole(userID, roleID string) error {
	err := p.session.GuildMemberRoleRemove(p.config.GuildID, userID, roleID)
	if err != nil {
		return fmt.Errorf("failed to remove role: %w", err)
	}
	return nil
}

// GetOrCreateRole gets an existing role or creates a new one
func (p *DiscordPlatform) GetOrCreateRole(name string) (*core.PlatformRole, error) {
	// Try to get existing role first
	if role, err := p.getRoleByName(name); err == nil {
		return &core.PlatformRole{
			ID:   role.ID,
			Name: role.Name,
		}, nil
	}
	
	// Create new role
	defaultColor := 7506394
	roleData := &discordgo.RoleParams{
		Name:  name,
		Color: &defaultColor,
	}
	
	role, err := p.session.GuildRoleCreate(p.config.GuildID, roleData)
	if err != nil {
		return nil, fmt.Errorf("failed to create role: %w", err)
	}
	
	return &core.PlatformRole{
		ID:   role.ID,
		Name: role.Name,
	}, nil
}

// GetRoleByID retrieves a role by its ID
func (p *DiscordPlatform) GetRoleByID(roleID string) (*core.PlatformRole, error) {
	roles, err := p.session.GuildRoles(p.config.GuildID)
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

// GetServerID returns the Discord guild ID
func (p *DiscordPlatform) GetServerID() string {
	return p.config.GuildID
}

// IsAdmin checks if a user is an admin (has the admin role)
func (p *DiscordPlatform) IsAdmin(userID string) (bool, error) {
	return p.HasRole(userID, p.config.AdminRoleID)
}

// Helper methods

func (p *DiscordPlatform) getRoleByName(name string) (*discordgo.Role, error) {
	roles, err := p.session.GuildRoles(p.config.GuildID)
	if err != nil {
		return nil, fmt.Errorf("failed to get guild roles: %w", err)
	}
	
	for _, role := range roles {
		if role.Name == name {
			return role, nil
		}
	}
	
	return nil, errors.New("role not found")
}

// Discord-specific methods for the verified address role

// AddVerifiedRole adds the verified address role to a user
func (p *DiscordPlatform) AddVerifiedRole(userID string) error {
	return p.AddRole(userID, p.config.VerifiedAddressRoleID)
}

// RemoveVerifiedRole removes the verified address role from a user
func (p *DiscordPlatform) RemoveVerifiedRole(userID string) error {
	return p.RemoveRole(userID, p.config.VerifiedAddressRoleID)
}