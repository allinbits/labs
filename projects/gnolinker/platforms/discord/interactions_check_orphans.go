package discord

import (
	"fmt"
	"strings"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/bwmarrin/discordgo"
)

// OrphanedRole represents a role that is orphaned in some way
type OrphanedRole struct {
	Type        string // "gno-side" or "discord-side"
	RealmPath   string
	RoleName    string
	DiscordRole *discordgo.Role
	RoleMapping *core.RoleMapping
}

func (h *InteractionHandlers) handleAdminCheckOrphansCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	// Check guild admin permissions
	userID := i.Member.User.ID
	isGuildAdmin, err := h.hasGuildAdminPermission(s, i.GuildID, userID)
	if err != nil || !isGuildAdmin {
		h.respondError(s, i, "You need Discord admin permissions (Administrator role or server owner) to check for orphaned roles.")
		return
	}

	// Defer response as this might take a moment
	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	}); err != nil {
		h.logger.Error("Failed to defer interaction response", "error", err)
		return
	}

	// Get all linked roles from gno.land
	linkedRoles, err := h.roleLinkingFlow.ListAllRolesByGuild(i.GuildID)
	if err != nil {
		h.logger.Error("Failed to list all roles by guild", "error", err, "guild_id", i.GuildID)
		h.respondDeferredError(s, i, "Failed to retrieve linked roles from gno.land.")
		return
	}

	// Get all Discord roles
	discordRoles, err := s.GuildRoles(i.GuildID)
	if err != nil {
		h.logger.Error("Failed to get guild roles", "error", err, "guild_id", i.GuildID)
		h.respondDeferredError(s, i, "Failed to retrieve Discord roles.")
		return
	}

	// Find orphaned roles
	orphans := h.findOrphanedRoles(linkedRoles, discordRoles)

	// Format and send response
	embed := h.formatOrphanedRolesEmbed(orphans)

	if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	}); err != nil {
		h.logger.Error("Failed to edit interaction response", "error", err)
	}
}

func (h *InteractionHandlers) findOrphanedRoles(linkedRoles []*core.RoleMapping, discordRoles []*discordgo.Role) []OrphanedRole {
	orphans := []OrphanedRole{}

	// Create a map of Discord role IDs for quick lookup
	discordRoleMap := make(map[string]*discordgo.Role)
	for _, role := range discordRoles {
		discordRoleMap[role.ID] = role
	}

	// Find gno-side orphans (linked roles where Discord role is deleted)
	for _, linkedRole := range linkedRoles {
		if _, exists := discordRoleMap[linkedRole.PlatformRole.ID]; !exists {
			orphans = append(orphans, OrphanedRole{
				Type:        "gno-side",
				RealmPath:   linkedRole.RealmPath,
				RoleName:    linkedRole.RealmRoleName,
				RoleMapping: linkedRole,
			})
		}
	}

	// Create a map of linked role IDs for quick lookup
	linkedRoleIDMap := make(map[string]bool)
	for _, linkedRole := range linkedRoles {
		linkedRoleIDMap[linkedRole.PlatformRole.ID] = true
	}

	// Find discord-side orphans (Discord roles that look like gno roles but aren't linked)
	for _, discordRole := range discordRoles {
		// Skip if this role is already linked
		if linkedRoleIDMap[discordRole.ID] {
			continue
		}

		// Check if the role name contains "gno.land/r/"
		if strings.Contains(discordRole.Name, "gno.land/r/") {
			// Try to parse the expected format: {roleName}-{realmPath}
			parts := strings.SplitN(discordRole.Name, "-", 2)
			if len(parts) == 2 && strings.HasPrefix(parts[1], "gno.land/r/") {
				orphans = append(orphans, OrphanedRole{
					Type:        "discord-side",
					RoleName:    parts[0],
					RealmPath:   parts[1],
					DiscordRole: discordRole,
				})
			}
		}
	}

	return orphans
}

func (h *InteractionHandlers) formatOrphanedRolesEmbed(orphans []OrphanedRole) *discordgo.MessageEmbed {
	if len(orphans) == 0 {
		return &discordgo.MessageEmbed{
			Title:       "✅ No Orphaned Roles",
			Description: "All roles are properly linked and synchronized!",
			Color:       0x00ff00, // Green
		}
	}

	// Separate orphans by type
	var gnoSideOrphans []OrphanedRole
	var discordSideOrphans []OrphanedRole

	for _, orphan := range orphans {
		if orphan.Type == "gno-side" {
			gnoSideOrphans = append(gnoSideOrphans, orphan)
		} else {
			discordSideOrphans = append(discordSideOrphans, orphan)
		}
	}

	// Build fields
	fields := []*discordgo.MessageEmbedField{}

	// Add gno-side orphans
	if len(gnoSideOrphans) > 0 {
		var value string
		for _, orphan := range gnoSideOrphans {
			value += fmt.Sprintf("• **%s** @ `%s`\n  Missing Discord role ID: `%s`\n",
				orphan.RoleName,
				orphan.RealmPath,
				orphan.RoleMapping.PlatformRole.ID)
		}
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "🔴 Gno-side Orphans (Deleted Discord Roles)",
			Value:  value + "\n*These roles exist in gno.land but their Discord roles were deleted.*",
			Inline: false,
		})
	}

	// Add discord-side orphans
	if len(discordSideOrphans) > 0 {
		var value string
		for _, orphan := range discordSideOrphans {
			value += fmt.Sprintf("• <@&%s> (`%s`)\n  Expected: **%s** @ `%s`\n",
				orphan.DiscordRole.ID,
				orphan.DiscordRole.Name,
				orphan.RoleName,
				orphan.RealmPath)
		}
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "🟡 Discord-side Orphans (Unlinked Roles)",
			Value:  value + "\n*These Discord roles look like gno-linked roles but aren't registered.*",
			Inline: false,
		})
	}

	// Add summary
	embed := &discordgo.MessageEmbed{
		Title:       "Orphaned Roles Check",
		Description: fmt.Sprintf("Found **%d** orphaned roles:", len(orphans)),
		Fields:      fields,
		Color:       0xFFA500, // Orange
		Footer: &discordgo.MessageEmbedFooter{
			Text: fmt.Sprintf("%d gno-side • %d discord-side", len(gnoSideOrphans), len(discordSideOrphans)),
		},
	}

	return embed
}
