package discord

import (
	"fmt"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/bwmarrin/discordgo"
)

// InteractionHandlers contains all interaction-based command handlers
type InteractionHandlers struct {
	userLinkingFlow workflows.UserLinkingWorkflow
	roleLinkingFlow workflows.RoleLinkingWorkflow
	syncFlow        workflows.SyncWorkflow
	configManager   *config.ConfigManager
	logger          core.Logger
}

// NewInteractionHandlers creates interaction handlers with workflow dependencies
func NewInteractionHandlers(
	userFlow workflows.UserLinkingWorkflow,
	roleFlow workflows.RoleLinkingWorkflow,
	syncFlow workflows.SyncWorkflow,
	configManager *config.ConfigManager,
	logger core.Logger,
) *InteractionHandlers {
	return &InteractionHandlers{
		userLinkingFlow: userFlow,
		roleLinkingFlow: roleFlow,
		syncFlow:        syncFlow,
		configManager:   configManager,
		logger:          logger,
	}
}

// RegisterSlashCommands registers all slash commands with Discord for a specific guild
func (h *InteractionHandlers) RegisterSlashCommands(s *discordgo.Session, guildID string) error {
	// Single command with all functionality as subcommands
	gnolinkerCommand := &discordgo.ApplicationCommand{
		Name:        "gnolinker",
		Description: "Link your Discord account to gno.land and manage realm roles",
		Options: []*discordgo.ApplicationCommandOption{
			// Link subcommand group
			{
				Type:        discordgo.ApplicationCommandOptionSubCommandGroup,
				Name:        "link",
				Description: "Link accounts and roles",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "address",
						Description: "Link your Discord account to a gno.land address",
						Options: []*discordgo.ApplicationCommandOption{
							{
								Type:        discordgo.ApplicationCommandOptionString,
								Name:        "address",
								Description: "Your gno.land address",
								Required:    true,
							},
						},
					},
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "role",
						Description: "Link a realm role to a Discord role (Admin only)",
						Options: []*discordgo.ApplicationCommandOption{
							{
								Type:        discordgo.ApplicationCommandOptionString,
								Name:        "role",
								Description: "The realm role name",
								Required:    true,
							},
							{
								Type:        discordgo.ApplicationCommandOptionString,
								Name:        "realm",
								Description: "The realm path",
								Required:    true,
							},
						},
					},
				},
			},
			// Verify subcommand group
			{
				Type:        discordgo.ApplicationCommandOptionSubCommandGroup,
				Name:        "verify",
				Description: "Verify account and role status",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "address",
						Description: "Verify your account linking status",
					},
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "role",
						Description: "Verify role linking status",
						Options: []*discordgo.ApplicationCommandOption{
							{
								Type:        discordgo.ApplicationCommandOptionString,
								Name:        "role",
								Description: "The realm role name",
								Required:    true,
							},
							{
								Type:        discordgo.ApplicationCommandOptionString,
								Name:        "realm",
								Description: "The realm path",
								Required:    true,
							},
						},
					},
				},
			},
			// Sync subcommand group
			{
				Type:        discordgo.ApplicationCommandOptionSubCommandGroup,
				Name:        "sync",
				Description: "Synchronize realm roles with Discord",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "roles",
						Description: "Sync your realm roles",
						Options: []*discordgo.ApplicationCommandOption{
							{
								Type:        discordgo.ApplicationCommandOptionString,
								Name:        "realm",
								Description: "The realm path to sync from",
								Required:    true,
							},
						},
					},
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "user",
						Description: "Sync roles for another user (Admin only)",
						Options: []*discordgo.ApplicationCommandOption{
							{
								Type:        discordgo.ApplicationCommandOptionString,
								Name:        "realm",
								Description: "The realm path",
								Required:    true,
							},
							{
								Type:        discordgo.ApplicationCommandOptionUser,
								Name:        "user",
								Description: "The user to sync roles for",
								Required:    true,
							},
						},
					},
				},
			},
			// Admin subcommand group
			{
				Type:        discordgo.ApplicationCommandOptionSubCommandGroup,
				Name:        "admin",
				Description: "Administrative commands (Admin only)",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "refresh-commands",
						Description: "Re-register slash commands for this guild",
					},
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "info",
						Description: "Show bot configuration information",
					},
				},
			},
			// Help subcommand
			{
				Type:        discordgo.ApplicationCommandOptionSubCommand,
				Name:        "help",
				Description: "Show available commands and usage information",
			},
		},
	}

	// Register the command for the specific guild
	_, err := s.ApplicationCommandCreate(s.State.User.ID, guildID, gnolinkerCommand)
	if err != nil {
		return fmt.Errorf("cannot create gnolinker command: %w", err)
	}

	h.logger.Info("Registered gnolinker slash command", "guild_id", guildID)
	return nil
}

// CleanupOldCommands removes all existing slash commands for a specific guild
func (h *InteractionHandlers) CleanupOldCommands(s *discordgo.Session, guildID string) error {
	h.logger.Info("Cleaning up old slash commands...", "guild_id", guildID)
	
	// Get all existing commands for the guild
	commands, err := s.ApplicationCommands(s.State.User.ID, guildID)
	if err != nil {
		return fmt.Errorf("failed to get commands: %w", err)
	}
	
	// Delete all commands for the guild
	for _, cmd := range commands {
		err := s.ApplicationCommandDelete(s.State.User.ID, guildID, cmd.ID)
		if err != nil {
			h.logger.Error("Failed to delete command", "command", cmd.Name, "error", err)
		} else {
			h.logger.Info("Deleted command", "command", cmd.Name)
		}
	}
	
	h.logger.Info("Cleanup completed", "commands_deleted", len(commands))
	return nil
}

// HandleInteraction handles all Discord interactions
func (h *InteractionHandlers) HandleInteraction(s *discordgo.Session, i *discordgo.InteractionCreate) {
	switch i.Type {
	case discordgo.InteractionApplicationCommand:
		h.handleSlashCommand(s, i)
	case discordgo.InteractionMessageComponent:
		h.handleComponent(s, i)
	}
}

func (h *InteractionHandlers) handleSlashCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	data := i.ApplicationCommandData()
	
	if data.Name != "gnolinker" {
		return
	}
	
	options := data.Options
	if len(options) == 0 {
		return
	}
	
	// Handle top-level subcommands (like help)
	if options[0].Type == discordgo.ApplicationCommandOptionSubCommand {
		switch options[0].Name {
		case "help":
			h.handleHelpCommand(s, i)
		}
		return
	}
	
	// Handle subcommand groups
	if options[0].Type == discordgo.ApplicationCommandOptionSubCommandGroup {
		group := options[0]
		if len(group.Options) == 0 {
			return
		}
		
		subcommand := group.Options[0]
		
		switch group.Name {
		case "link":
			switch subcommand.Name {
			case "address":
				h.handleLinkAddressCommand(s, i, subcommand.Options)
			case "role":
				h.handleLinkRoleCommand(s, i, subcommand.Options)
			}
		case "verify":
			switch subcommand.Name {
			case "address":
				h.handleVerifyAddressCommand(s, i)
			case "role":
				h.handleVerifyRoleCommand(s, i, subcommand.Options)
			}
		case "sync":
			switch subcommand.Name {
			case "roles":
				h.handleSyncRolesCommand(s, i, subcommand.Options)
			case "user":
				h.handleSyncUserCommand(s, i, subcommand.Options)
			}
		case "admin":
			switch subcommand.Name {
			case "refresh-commands":
				h.handleAdminRefreshCommandsCommand(s, i)
			case "info":
				h.handleAdminInfoCommand(s, i)
			}
		}
	}
}

func (h *InteractionHandlers) handleLinkAddressCommand(s *discordgo.Session, i *discordgo.InteractionCreate, options []*discordgo.ApplicationCommandInteractionDataOption) {
	address := options[0].StringValue()
	userID := i.Member.User.ID

	// Generate claim
	claim, err := h.userLinkingFlow.GenerateClaim(userID, address)
	if err != nil {
		h.logger.Error("Failed to generate user claim", "error", err, "user_id", userID, "address", address)
		h.respondError(s, i, "Failed to generate claim. Please try again.")
		return
	}

	// Create response with claim and URL
	claimURL := h.userLinkingFlow.GetClaimURL(claim)
	embed := &discordgo.MessageEmbed{
		Title:       "Link Your Account",
		Description: "Here's your signed claim to link your Discord account to gno.land:",
		Fields: []*discordgo.MessageEmbedField{
			{
				Name:  "Claim Signature",
				Value: fmt.Sprintf("```\n%s\n```", claim.Signature),
			},
		},
		Color: 0x00ff00,
	}

	// Add button to claim on gno.land
	components := []discordgo.MessageComponent{
		discordgo.ActionsRow{
			Components: []discordgo.MessageComponent{
				discordgo.Button{
					Label: "Claim on gno.land",
					Style: discordgo.LinkButton,
					URL:   claimURL,
					Emoji: &discordgo.ComponentEmoji{
						Name: "🔗",
					},
				},
			},
		},
	}

	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds:     []*discordgo.MessageEmbed{embed},
			Components: components,
			Flags:      discordgo.MessageFlagsEphemeral,
		},
	})
}

func (h *InteractionHandlers) handleVerifyAddressCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	// Get user ID
	userID := i.Member.User.ID

	// Defer response to prevent timeout
	err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	})
	if err != nil {
		h.logger.Error("Failed to defer response", "error", err, "user_id", userID)
		return
	}

	// Get guild configuration
	guildConfig, err := h.configManager.EnsureGuildConfig(s, i.GuildID)
	if err != nil {
		h.logger.Error("Failed to get guild config", "error", err, "guild_id", i.GuildID)
		h.followUpError(s, i, "Failed to get guild configuration.")
		return
	}

	// Get linked address
	address, err := h.userLinkingFlow.GetLinkedAddress(userID)
	if err != nil {
		h.logger.Error("Failed to get linked address", "error", err, "user_id", userID)
		h.followUpError(s, i, "Failed to check linked address.")
		return
	}

	var embed *discordgo.MessageEmbed
	if address == "" {
		// Remove verified role if no address is linked and role is configured
		if guildConfig.HasVerifiedRole() {
			s.GuildMemberRoleRemove(i.GuildID, userID, guildConfig.VerifiedRoleID)
		}
		
		embed = &discordgo.MessageEmbed{
			Title:       "No Linked Address",
			Description: "Your Discord account is not linked to any gno.land address.",
			Color:       0xff0000,
		}
	} else {
		// Add verified role if address is linked and role is configured
		if guildConfig.HasVerifiedRole() {
			s.GuildMemberRoleAdd(i.GuildID, userID, guildConfig.VerifiedRoleID)
		}
		
		embed = &discordgo.MessageEmbed{
			Title:       "Address Verified ✅",
			Description: fmt.Sprintf("Your Discord account is linked to:\n`%s`", address),
			Color:       0x00ff00,
		}
	}

	_, err = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	})
	if err != nil {
		h.logger.Error("Failed to edit response", "error", err, "user_id", userID)
	}
}

func (h *InteractionHandlers) handleSyncRolesCommand(s *discordgo.Session, i *discordgo.InteractionCreate, options []*discordgo.ApplicationCommandInteractionDataOption) {
	realmPath := options[0].StringValue()
	userID := i.Member.User.ID

	// Defer response as sync might take time
	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	})

	// Sync roles
	statuses, err := h.syncFlow.SyncUserRoles(userID, realmPath, i.GuildID)
	if err != nil {
		h.logger.Error("Failed to sync user roles", "error", err, "user_id", userID, "realm_path", realmPath)
		h.followUpError(s, i, "Failed to sync roles: "+err.Error())
		return
	}

	// Build response embed
	embed := &discordgo.MessageEmbed{
		Title:       fmt.Sprintf("Role Sync Complete - %s", realmPath),
		Description: "Your realm roles have been synchronized:",
		Fields:      []*discordgo.MessageEmbedField{},
		Color:       0x00ff00,
	}

	// Update Discord roles and track results
	for _, status := range statuses {
		// Update Discord role
		if status.IsMember {
			err := s.GuildMemberRoleAdd(i.GuildID, userID, status.RoleMapping.PlatformRole.ID)
			if err != nil {
				h.logger.Error("Failed to add role", "error", err, "user_id", userID, "role_id", status.RoleMapping.PlatformRole.ID)
			}
		} else {
			err := s.GuildMemberRoleRemove(i.GuildID, userID, status.RoleMapping.PlatformRole.ID)
			if err != nil {
				h.logger.Error("Failed to remove role", "error", err, "user_id", userID, "role_id", status.RoleMapping.PlatformRole.ID)
			}
		}

		statusEmoji := "❌"
		if status.IsMember {
			statusEmoji = "✅"
		}
		
		embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
			Name:   fmt.Sprintf("%s %s", statusEmoji, status.RoleMapping.RealmRoleName),
			Value:  fmt.Sprintf("Discord: %s", status.RoleMapping.PlatformRole.Name),
			Inline: false,
		})
	}

	s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	})
}

func (h *InteractionHandlers) handleHelpCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	embed := &discordgo.MessageEmbed{
		Title:       "GnoLinker Help",
		Description: "Link your Discord account to gno.land and sync your realm roles!",
		Fields: []*discordgo.MessageEmbedField{
			{
				Name:  "📎 Link Commands",
				Value: "`/gnolinker link address <address>` - Link your Discord to a gno.land address\n`/gnolinker link role <role> <realm>` - Link realm role to Discord role (Gno.land Admin)",
			},
			{
				Name:  "✅ Verify Commands",
				Value: "`/gnolinker verify address` - Check your account linking status\n`/gnolinker verify role <role> <realm>` - Check role linking status",
			},
			{
				Name:  "🔄 Sync Commands",
				Value: "`/gnolinker sync roles <realm>` - Sync your realm roles\n`/gnolinker sync user <realm> <user>` - Sync another user's roles (Gno.land Admin)",
			},
			{
				Name:  "⚙️ Guild Admin Commands",
				Value: "`/gnolinker admin refresh-commands` - Re-register slash commands (Discord Admin)\n`/gnolinker admin info` - Show bot configuration (Discord Admin)",
			},
			{
				Name:  "🔑 Permission Types",
				Value: "**Gno.land Admin**: Requires configured admin role for realm management\n**Discord Admin**: Requires Administrator permission or server owner",
			},
			{
				Name:  "ℹ️ How it works",
				Value: "1. Link your Discord to gno.land address\n2. Gno.land admin links realm roles to Discord roles\n3. Sync your roles to get Discord permissions",
			},
		},
		Color: 0x5865F2,
		Footer: &discordgo.MessageEmbedFooter{
			Text: "All responses are private to you • Need help? Contact an admin!",
		},
	}

	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds: []*discordgo.MessageEmbed{embed},
			Flags:  discordgo.MessageFlagsEphemeral,
		},
	})
}

func (h *InteractionHandlers) handleLinkRoleCommand(s *discordgo.Session, i *discordgo.InteractionCreate, options []*discordgo.ApplicationCommandInteractionDataOption) {
	// Check role admin permissions (for realm role management)
	userID := i.Member.User.ID
	isRoleAdmin, err := h.hasRoleAdminPermission(s, i.GuildID, userID)
	if err != nil || !isRoleAdmin {
		h.respondError(s, i, "You need gno.land admin permissions to link realm roles. Contact a server admin to get the configured admin role.")
		return
	}

	roleName := options[0].StringValue()
	realmPath := options[1].StringValue()

	// Defer response
	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	})

	// Create confirmation embed
	embed := &discordgo.MessageEmbed{
		Title:       "Confirm Role Linking",
		Description: fmt.Sprintf("Link realm role `%s` from `%s` to a Discord role?", roleName, realmPath),
		Color:       0xffff00,
	}

	components := []discordgo.MessageComponent{
		discordgo.ActionsRow{
			Components: []discordgo.MessageComponent{
				discordgo.Button{
					Label:    "Confirm",
					Style:    discordgo.SuccessButton,
					CustomID: fmt.Sprintf("confirm_link_%s_%s", roleName, realmPath),
				},
				discordgo.Button{
					Label:    "Cancel",
					Style:    discordgo.DangerButton,
					CustomID: "cancel_link",
				},
			},
		},
	}

	s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds:     &[]*discordgo.MessageEmbed{embed},
		Components: &components,
	})
}

func (h *InteractionHandlers) handleVerifyRoleCommand(s *discordgo.Session, i *discordgo.InteractionCreate, options []*discordgo.ApplicationCommandInteractionDataOption) {
	roleName := options[0].StringValue()
	realmPath := options[1].StringValue()

	// Get linked role
	roleMapping, err := h.roleLinkingFlow.GetLinkedRole(realmPath, roleName, i.GuildID)
	if err != nil {
		h.logger.Error("Failed to get linked role", "error", err, "role_name", roleName, "realm_path", realmPath)
		h.respondError(s, i, "Failed to check linked role.")
		return
	}

	embed := &discordgo.MessageEmbed{
		Title: "Role Linking Status",
		Fields: []*discordgo.MessageEmbedField{
			{
				Name:   "Realm Role",
				Value:  fmt.Sprintf("`%s` @ `%s`", roleName, realmPath),
				Inline: true,
			},
			{
				Name:   "Discord Role",
				Value:  fmt.Sprintf("<@&%s>", roleMapping.PlatformRole.ID),
				Inline: true,
			},
		},
		Color: 0x00ff00,
	}

	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds: []*discordgo.MessageEmbed{embed},
			Flags:  discordgo.MessageFlagsEphemeral,
		},
	})
}

func (h *InteractionHandlers) handleSyncUserCommand(s *discordgo.Session, i *discordgo.InteractionCreate, options []*discordgo.ApplicationCommandInteractionDataOption) {
	// Check role admin permissions (for managing other users' realm roles)
	userID := i.Member.User.ID
	isRoleAdmin, err := h.hasRoleAdminPermission(s, i.GuildID, userID)
	if err != nil || !isRoleAdmin {
		h.respondError(s, i, "You need gno.land admin permissions to sync other users' roles. Contact a server admin to get the configured admin role.")
		return
	}

	realmPath := options[0].StringValue()
	targetUser := options[1].UserValue(s)

	// Defer response
	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	})

	// Sync roles
	statuses, err := h.syncFlow.SyncUserRoles(targetUser.ID, realmPath, i.GuildID)
	if err != nil {
		h.logger.Error("Failed to sync user roles", "error", err, "target_user_id", targetUser.ID, "realm_path", realmPath)
		h.followUpError(s, i, "Failed to sync roles: "+err.Error())
		return
	}

	// Build response
	embed := &discordgo.MessageEmbed{
		Title:       fmt.Sprintf("Synced Roles for %s", targetUser.Username),
		Description: fmt.Sprintf("Realm: `%s`", realmPath),
		Fields:      []*discordgo.MessageEmbedField{},
		Color:       0x00ff00,
	}

	// Update Discord roles for target user
	for _, status := range statuses {
		// Update Discord role
		if status.IsMember {
			err := s.GuildMemberRoleAdd(i.GuildID, targetUser.ID, status.RoleMapping.PlatformRole.ID)
			if err != nil {
				h.logger.Error("Failed to add role", "error", err, "target_user_id", targetUser.ID, "role_id", status.RoleMapping.PlatformRole.ID)
			}
		} else {
			err := s.GuildMemberRoleRemove(i.GuildID, targetUser.ID, status.RoleMapping.PlatformRole.ID)
			if err != nil {
				h.logger.Error("Failed to remove role", "error", err, "target_user_id", targetUser.ID, "role_id", status.RoleMapping.PlatformRole.ID)
			}
		}

		statusEmoji := "❌"
		if status.IsMember {
			statusEmoji = "✅"
		}
		
		embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
			Name:   fmt.Sprintf("%s %s", statusEmoji, status.RoleMapping.RealmRoleName),
			Value:  fmt.Sprintf("Discord: %s", status.RoleMapping.PlatformRole.Name),
			Inline: false,
		})
	}

	s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	})
}

func (h *InteractionHandlers) handleComponent(s *discordgo.Session, i *discordgo.InteractionCreate) {
	customID := i.MessageComponentData().CustomID

	if customID == "cancel_link" {
		s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
			Type: discordgo.InteractionResponseUpdateMessage,
			Data: &discordgo.InteractionResponseData{
				Content:    "❌ Operation cancelled.",
				Components: []discordgo.MessageComponent{},
				Embeds:     []*discordgo.MessageEmbed{},
			},
		})
		return
	}

	// Handle confirm_link_{roleName}_{realmPath}
	if len(customID) > 13 && customID[:13] == "confirm_link_" {
		h.handleConfirmLinkRole(s, i, customID[13:])
	}
}

func (h *InteractionHandlers) handleConfirmLinkRole(s *discordgo.Session, i *discordgo.InteractionCreate, params string) {
	// Parse roleName and realmPath from params
	parts := parseRoleLinkParams(params)
	if len(parts) < 2 {
		s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
			Type: discordgo.InteractionResponseUpdateMessage,
			Data: &discordgo.InteractionResponseData{
				Content:    "❌ Invalid parameters.",
				Components: []discordgo.MessageComponent{},
				Embeds:     []*discordgo.MessageEmbed{},
			},
		})
		return
	}
	
	roleName := parts[0]
	realmPath := parts[1]
	userID := i.Member.User.ID
	
	// Update to show processing
	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseUpdateMessage,
		Data: &discordgo.InteractionResponseData{
			Content:    "⏳ Creating role link...",
			Components: []discordgo.MessageComponent{},
			Embeds:     []*discordgo.MessageEmbed{},
		},
	})
	
	// Create or get the Discord role using safe role creation
	discordRoleName := roleName + "-" + realmPath
	platformRole, err := h.getOrCreateRole(s, i.GuildID, discordRoleName)
	if err != nil {
		h.logger.Error("Failed to create role", "error", err, "discord_role_name", discordRoleName)
		s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Content: &[]string{"❌ Failed to create Discord role."}[0],
		})
		return
	}
	
	// Generate claim
	claim, err := h.roleLinkingFlow.GenerateClaim(userID, i.GuildID, platformRole.ID, roleName, realmPath)
	if err != nil {
		h.logger.Error("Failed to generate role claim", "error", err, "user_id", userID, "role_name", roleName, "realm_path", realmPath)
		s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Content: &[]string{"❌ Failed to generate claim."}[0],
		})
		return
	}
	
	// Create response
	claimURL := h.roleLinkingFlow.GetClaimURL(claim)
	embed := &discordgo.MessageEmbed{
		Title:       "Role Link Created",
		Description: fmt.Sprintf("Link Discord role `%s` to realm role `%s` at `%s`", platformRole.Name, roleName, realmPath),
		Fields: []*discordgo.MessageEmbedField{
			{
				Name:  "Claim Signature",
				Value: fmt.Sprintf("```\n%s\n```", claim.Signature),
			},
		},
		Color: 0x00ff00,
	}
	
	components := []discordgo.MessageComponent{
		discordgo.ActionsRow{
			Components: []discordgo.MessageComponent{
				discordgo.Button{
					Label: "Claim on gno.land",
					Style: discordgo.LinkButton,
					URL:   claimURL,
					Emoji: &discordgo.ComponentEmoji{
						Name: "🔗",
					},
				},
			},
		},
	}
	
	s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Content:    &[]string{""}[0],
		Embeds:     &[]*discordgo.MessageEmbed{embed},
		Components: &components,
	})
}

// Helper functions

func (h *InteractionHandlers) respondError(s *discordgo.Session, i *discordgo.InteractionCreate, message string) {
	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Content: fmt.Sprintf("❌ %s", message),
			Flags:   discordgo.MessageFlagsEphemeral,
		},
	})
}

func (h *InteractionHandlers) followUpError(s *discordgo.Session, i *discordgo.InteractionCreate, message string) {
	s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Content: &message,
	})
}

// Helper function to parse role link parameters
func parseRoleLinkParams(params string) []string {
	// Simple split by underscore for now
	// Format: roleName_realmPath
	parts := make([]string, 0)
	lastUnderscore := -1
	
	// Find the last underscore to split roleName and realmPath
	for i := len(params) - 1; i >= 0; i-- {
		if params[i] == '_' {
			lastUnderscore = i
			break
		}
	}
	
	if lastUnderscore > 0 && lastUnderscore < len(params)-1 {
		parts = append(parts, params[:lastUnderscore])
		parts = append(parts, params[lastUnderscore+1:])
	}
	
	return parts
}

// Helper function to get role by name
func (h *InteractionHandlers) getRoleByName(s *discordgo.Session, guildID, name string) (*core.PlatformRole, error) {
	roles, err := s.GuildRoles(guildID)
	if err != nil {
		return nil, err
	}
	
	for _, role := range roles {
		if role.Name == name {
			return &core.PlatformRole{
				ID:   role.ID,
				Name: role.Name,
			}, nil
		}
	}
	
	return nil, fmt.Errorf("role not found")
}

// getOrCreateRole gets an existing role or creates a new one with distributed locking
func (h *InteractionHandlers) getOrCreateRole(s *discordgo.Session, guildID, name string) (*core.PlatformRole, error) {
	// First try to find existing role
	if role, err := h.getRoleByName(s, guildID, name); err == nil {
		return role, nil
	}

	// Create a temporary role manager for this operation
	lockManager := h.configManager.GetLockManager()
	roleManager := NewRoleManager(s, lockManager, h.logger)
	
	// Use the role manager to safely create the role
	defaultColor := 7506394
	return roleManager.GetOrCreateRole(guildID, name, &defaultColor)
}

// Helper function to check if user has a role
func (h *InteractionHandlers) hasRole(s *discordgo.Session, guildID, userID, roleID string) (bool, error) {
	member, err := s.GuildMember(guildID, userID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild member: %w", err)
	}
	
	for _, memberRoleID := range member.Roles {
		if memberRoleID == roleID {
			return true, nil
		}
	}
	
	return false, nil
}

// Check if user has role admin permissions (for gno.land realm management)
func (h *InteractionHandlers) hasRoleAdminPermission(s *discordgo.Session, guildID, userID string) (bool, error) {
	// Get guild configuration
	guildConfig, err := h.configManager.GetGuildConfig(guildID)
	if err != nil {
		// If no config exists, fall back to Discord permissions
		return h.hasGuildAdminPermission(s, guildID, userID)
	}

	// If admin role is configured, check it
	if guildConfig.HasAdminRole() {
		return h.hasRole(s, guildID, userID, guildConfig.AdminRoleID)
	}

	// If no admin role configured, fall back to Discord permissions
	return h.hasGuildAdminPermission(s, guildID, userID)
}

// Check if user has guild admin permissions (for Discord server management)
func (h *InteractionHandlers) hasGuildAdminPermission(s *discordgo.Session, guildID, userID string) (bool, error) {
	// First check if they're the guild owner
	guild, err := s.Guild(guildID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild: %w", err)
	}
	
	if guild.OwnerID == userID {
		return true, nil
	}
	
	// Check if user has Administrator permission
	permissions, err := s.UserChannelPermissions(userID, guildID)
	if err != nil {
		return false, fmt.Errorf("failed to get user permissions: %w", err)
	}
	
	return (permissions & discordgo.PermissionAdministrator) != 0, nil
}

// Admin command handlers

func (h *InteractionHandlers) handleAdminRefreshCommandsCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	// Check guild admin permissions (for Discord server management)
	userID := i.Member.User.ID
	isGuildAdmin, err := h.hasGuildAdminPermission(s, i.GuildID, userID)
	if err != nil || !isGuildAdmin {
		h.respondError(s, i, "You need Discord admin permissions (Administrator role or server owner) to refresh commands.")
		return
	}

	// Defer response
	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	})

	// Re-register slash commands for this guild
	if err := h.RegisterSlashCommands(s, i.GuildID); err != nil {
		h.logger.Error("Failed to refresh commands", "guild_id", i.GuildID, "error", err)
		embed := &discordgo.MessageEmbed{
			Title:       "Command Refresh Failed",
			Description: "Failed to refresh slash commands. Please try again.",
			Color:       0xff0000,
		}
		s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Embeds: &[]*discordgo.MessageEmbed{embed},
		})
		return
	}

	embed := &discordgo.MessageEmbed{
		Title:       "Commands Refreshed",
		Description: "Successfully refreshed slash commands for this guild.",
		Color:       0x00ff00,
	}

	s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	})
}

func (h *InteractionHandlers) handleAdminInfoCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	// Check guild admin permissions (for viewing Discord server bot info)
	userID := i.Member.User.ID
	isGuildAdmin, err := h.hasGuildAdminPermission(s, i.GuildID, userID)
	if err != nil || !isGuildAdmin {
		h.respondError(s, i, "You need Discord admin permissions (Administrator role or server owner) to view bot info.")
		return
	}

	// Get guild info
	guild, err := s.Guild(i.GuildID)
	if err != nil {
		h.respondError(s, i, "Failed to get guild information.")
		return
	}

	// Get guild configuration
	guildConfig, err := h.configManager.EnsureGuildConfig(s, i.GuildID)
	if err != nil {
		h.respondError(s, i, "Failed to get guild configuration.")
		return
	}

	// Build configuration fields
	fields := []*discordgo.MessageEmbedField{
		{
			Name:   "Guild Info",
			Value:  fmt.Sprintf("Name: %s\nID: %s", guild.Name, guild.ID),
			Inline: false,
		},
	}

	// Admin role info
	if guildConfig.HasAdminRole() {
		adminRoleName := "Unknown"
		if role, err := s.State.Role(i.GuildID, guildConfig.AdminRoleID); err == nil {
			adminRoleName = role.Name
		}
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "Admin Role",
			Value:  fmt.Sprintf("%s\n`%s`", adminRoleName, guildConfig.AdminRoleID),
			Inline: true,
		})
	} else {
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "Admin Role",
			Value:  "Auto-detected from Discord permissions",
			Inline: true,
		})
	}

	// Verified role info
	if guildConfig.HasVerifiedRole() {
		verifiedRoleName := "Unknown"
		if role, err := s.State.Role(i.GuildID, guildConfig.VerifiedRoleID); err == nil {
			verifiedRoleName = role.Name
		}
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "Verified Role",
			Value:  fmt.Sprintf("%s\n`%s`", verifiedRoleName, guildConfig.VerifiedRoleID),
			Inline: true,
		})
	} else {
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "Verified Role",
			Value:  "Not configured",
			Inline: true,
		})
	}

	// Storage info
	fields = append(fields, &discordgo.MessageEmbedField{
		Name:   "Storage",
		Value:  "Multi-guild configuration enabled",
		Inline: false,
	})

	embed := &discordgo.MessageEmbed{
		Title:       "Bot Configuration",
		Description: "Current bot configuration for this guild:",
		Fields:      fields,
		Color:       0x5865F2,
	}

	s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds: []*discordgo.MessageEmbed{embed},
			Flags:  discordgo.MessageFlagsEphemeral,
		},
	})
}