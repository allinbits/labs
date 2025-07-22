package discord

import (
	"fmt"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/bwmarrin/discordgo"
)

func (h *InteractionHandlers) handleAdminListRolesCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	// Check guild admin permissions
	userID := i.Member.User.ID
	isGuildAdmin, err := h.hasGuildAdminPermission(s, i.GuildID, userID)
	if err != nil || !isGuildAdmin {
		h.respondError(s, i, "You need Discord admin permissions (Administrator role or server owner) to list all roles.")
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

	// Get all linked roles for this guild
	linkedRoles, err := h.roleLinkingFlow.ListAllRolesByGuild(i.GuildID)
	if err != nil {
		h.logger.Error("Failed to list all roles by guild", "error", err, "guild_id", i.GuildID)
		h.respondDeferredError(s, i, "Failed to retrieve linked roles.")
		return
	}

	if len(linkedRoles) == 0 {
		embed := &discordgo.MessageEmbed{
			Title:       "No Linked Roles",
			Description: "No roles have been linked in this guild yet.",
			Color:       0xFFA500, // Orange
		}
		if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Embeds: &[]*discordgo.MessageEmbed{embed},
		}); err != nil {
			h.logger.Error("Failed to edit interaction response", "error", err)
		}
		return
	}

	// Group roles by realm
	rolesByRealm := make(map[string][]*core.RoleMapping)
	for _, role := range linkedRoles {
		rolesByRealm[role.RealmPath] = append(rolesByRealm[role.RealmPath], role)
	}

	// Build embed fields
	fields := make([]*discordgo.MessageEmbedField, 0, len(rolesByRealm))
	totalRoles := 0

	for realmPath, roles := range rolesByRealm {
		var roleList string
		for _, role := range roles {
			roleList += fmt.Sprintf("• **%s** → <@&%s>\n", role.RealmRoleName, role.PlatformRole.ID)
			totalRoles++
		}

		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   realmPath,
			Value:  roleList,
			Inline: false,
		})
	}

	embed := &discordgo.MessageEmbed{
		Title:       "All Linked Roles",
		Description: fmt.Sprintf("Found **%d** linked roles across **%d** realms:", totalRoles, len(rolesByRealm)),
		Fields:      fields,
		Color:       0x5865F2, // Discord blurple
		Footer: &discordgo.MessageEmbedFooter{
			Text: "Use /gnolinker verify role to check specific role status",
		},
	}

	if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	}); err != nil {
		h.logger.Error("Failed to edit interaction response", "error", err)
	}
}

// Helper function for deferred error responses
func (h *InteractionHandlers) respondDeferredError(s *discordgo.Session, i *discordgo.InteractionCreate, message string) {
	embed := &discordgo.MessageEmbed{
		Title:       "Error",
		Description: fmt.Sprintf("❌ %s", message),
		Color:       0xff0000,
	}

	if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	}); err != nil {
		h.logger.Error("Failed to edit interaction response with error", "error", err, "message", message)
	}
}
