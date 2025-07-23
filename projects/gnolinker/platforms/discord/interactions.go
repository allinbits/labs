package discord

import (
	"fmt"
	"strings"

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

// GetExpectedCommands returns the canonical command definitions that should exist
func (h *InteractionHandlers) GetExpectedCommands() []*discordgo.ApplicationCommand {
	// Single command with all functionality as subcommands
	gnolinkerCommand := &discordgo.ApplicationCommand{
		Name:        "gnolinker",
		Description: "Link your Discord account to gno.land and manage realm roles",
		Options: []*discordgo.ApplicationCommandOption{
			// Link subcommand
			{
				Type:        discordgo.ApplicationCommandOptionSubCommand,
				Name:        "link",
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
			// Unlink subcommand
			{
				Type:        discordgo.ApplicationCommandOptionSubCommand,
				Name:        "unlink",
				Description: "Unlink your Discord account from your gno.land address",
			},
			// Admin subcommand group
			{
				Type:        discordgo.ApplicationCommandOptionSubCommandGroup,
				Name:        "admin",
				Description: "Administrative commands (Admin only)",
				Options: []*discordgo.ApplicationCommandOption{
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "info",
						Description: "Show bot configuration information",
					},
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "link-role",
						Description: "Link a realm role to a Discord role",
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
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "unlink-role",
						Description: "Unlink a realm role from a Discord role",
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
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "list-roles",
						Description: "List all linked roles across all realms",
					},
					{
						Type:        discordgo.ApplicationCommandOptionSubCommand,
						Name:        "check-orphans",
						Description: "Find orphaned roles (deleted or unlinked)",
					},
				},
			},
			// Status subcommand
			{
				Type:        discordgo.ApplicationCommandOptionSubCommand,
				Name:        "status",
				Description: "Show your personal linking status and roles",
			},
			// Help subcommand
			{
				Type:        discordgo.ApplicationCommandOptionSubCommand,
				Name:        "help",
				Description: "Show available commands and usage information",
			},
		},
	}

	return []*discordgo.ApplicationCommand{gnolinkerCommand}
}

// SyncSlashCommands intelligently syncs command definitions with Discord
func (h *InteractionHandlers) SyncSlashCommands(s *discordgo.Session, guildID string) error {
	// Get expected commands
	expectedCommands := h.GetExpectedCommands()

	// Get current Discord commands
	currentCommands, err := s.ApplicationCommands(s.State.User.ID, guildID)
	if err != nil {
		return fmt.Errorf("failed to get current commands: %w", err)
	}

	h.logger.Info("Starting command synchronization",
		"guild_id", guildID,
		"expected_commands", len(expectedCommands),
		"current_commands", len(currentCommands))

	// Compare and determine changes needed
	toCreate, toUpdate, toDelete := h.compareCommands(expectedCommands, currentCommands)

	// Apply changes
	changesMade := 0

	// Delete obsolete commands
	for _, cmd := range toDelete {
		h.logger.Info("Deleting obsolete command", "guild_id", guildID, "command", cmd.Name)
		err := s.ApplicationCommandDelete(s.State.User.ID, guildID, cmd.ID)
		if err != nil {
			h.logger.Error("Failed to delete command", "guild_id", guildID, "command", cmd.Name, "error", err)
		} else {
			changesMade++
		}
	}

	// Create new commands
	for _, cmd := range toCreate {
		h.logger.Info("Creating new command", "guild_id", guildID, "command", cmd.Name)
		_, err := s.ApplicationCommandCreate(s.State.User.ID, guildID, cmd)
		if err != nil {
			h.logger.Error("Failed to create command", "guild_id", guildID, "command", cmd.Name, "error", err)
		} else {
			changesMade++
		}
	}

	// Update modified commands
	for _, update := range toUpdate {
		h.logger.Info("Updating modified command", "guild_id", guildID, "command", update.expected.Name)
		_, err := s.ApplicationCommandEdit(s.State.User.ID, guildID, update.current.ID, update.expected)
		if err != nil {
			h.logger.Error("Failed to update command", "guild_id", guildID, "command", update.expected.Name, "error", err)
		} else {
			changesMade++
		}
	}

	if changesMade > 0 {
		h.logger.Info("Command synchronization completed", "guild_id", guildID, "changes_made", changesMade)
	} else {
		h.logger.Debug("Commands already in sync", "guild_id", guildID)
	}

	return nil
}

// CommandUpdate represents a command that needs to be updated
type CommandUpdate struct {
	current  *discordgo.ApplicationCommand
	expected *discordgo.ApplicationCommand
}

// compareCommands compares expected vs current commands and returns what changes are needed
func (h *InteractionHandlers) compareCommands(expected, current []*discordgo.ApplicationCommand) (
	toCreate []*discordgo.ApplicationCommand,
	toUpdate []CommandUpdate,
	toDelete []*discordgo.ApplicationCommand,
) {
	// Create maps for efficient lookup
	expectedMap := make(map[string]*discordgo.ApplicationCommand)
	currentMap := make(map[string]*discordgo.ApplicationCommand)

	for _, cmd := range expected {
		expectedMap[cmd.Name] = cmd
	}

	for _, cmd := range current {
		currentMap[cmd.Name] = cmd
	}

	// Find commands to create (in expected but not in current)
	for _, expectedCmd := range expected {
		if _, exists := currentMap[expectedCmd.Name]; !exists {
			toCreate = append(toCreate, expectedCmd)
		}
	}

	// Find commands to delete (in current but not in expected)
	for _, currentCmd := range current {
		if _, exists := expectedMap[currentCmd.Name]; !exists {
			toDelete = append(toDelete, currentCmd)
		}
	}

	// Find commands to update (exists in both but different)
	for _, expectedCmd := range expected {
		if currentCmd, exists := currentMap[expectedCmd.Name]; exists {
			if !h.commandsEqual(expectedCmd, currentCmd) {
				toUpdate = append(toUpdate, CommandUpdate{
					current:  currentCmd,
					expected: expectedCmd,
				})
			}
		}
	}

	return toCreate, toUpdate, toDelete
}

// commandsEqual compares two commands for equality (ignoring ID and other Discord-managed fields)
func (h *InteractionHandlers) commandsEqual(expected, current *discordgo.ApplicationCommand) bool {
	// Compare basic fields
	if expected.Name != current.Name ||
		expected.Description != current.Description ||
		expected.Type != current.Type {
		return false
	}

	// Compare options
	return h.optionsEqual(expected.Options, current.Options)
}

// optionsEqual compares two option slices for equality
func (h *InteractionHandlers) optionsEqual(expected, current []*discordgo.ApplicationCommandOption) bool {
	if len(expected) != len(current) {
		return false
	}

	// Create maps for comparison (order shouldn't matter for our use case)
	expectedMap := make(map[string]*discordgo.ApplicationCommandOption)
	currentMap := make(map[string]*discordgo.ApplicationCommandOption)

	for _, opt := range expected {
		expectedMap[opt.Name] = opt
	}

	for _, opt := range current {
		currentMap[opt.Name] = opt
	}

	// Check if all expected options exist and match in current
	for name, expectedOpt := range expectedMap {
		currentOpt, exists := currentMap[name]
		if !exists {
			return false
		}

		if !h.optionEqual(expectedOpt, currentOpt) {
			return false
		}
	}

	return true
}

// optionEqual compares two individual options for equality
func (h *InteractionHandlers) optionEqual(expected, current *discordgo.ApplicationCommandOption) bool {
	// Compare basic fields
	if expected.Name != current.Name ||
		expected.Description != current.Description ||
		expected.Type != current.Type ||
		expected.Required != current.Required {
		return false
	}

	// Recursively compare sub-options
	return h.optionsEqual(expected.Options, current.Options)
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

	// Handle top-level subcommands (like help, status, link, unlink)
	if options[0].Type == discordgo.ApplicationCommandOptionSubCommand {
		switch options[0].Name {
		case "help":
			h.handleHelpCommand(s, i)
		case "status":
			h.handleStatusCommand(s, i)
		case "link":
			h.handleLinkAddressCommand(s, i, options[0].Options)
		case "unlink":
			h.handleUnlinkAddressCommand(s, i)
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
		case "admin":
			switch subcommand.Name {
			case "info":
				h.handleAdminInfoCommand(s, i)
			case "link-role":
				h.handleLinkRoleCommand(s, i, subcommand.Options)
			case "unlink-role":
				h.handleUnlinkRoleCommand(s, i, subcommand.Options)
			case "list-roles":
				h.handleAdminListRolesCommand(s, i)
			case "check-orphans":
				h.handleAdminCheckOrphansCommand(s, i)
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
		Description: fmt.Sprintf("Ready to link your Discord account to `%s`", address),
		Color:       0x00ff00,
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

	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds:     []*discordgo.MessageEmbed{embed},
			Components: components,
			Flags:      discordgo.MessageFlagsEphemeral,
		},
	}); err != nil {
		h.logger.Error("Failed to respond to interaction", "error", err)
	}
}

func (h *InteractionHandlers) handleUnlinkAddressCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
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

	// 1. Look up the gno address linked to this Discord ID
	linkedAddress, err := h.userLinkingFlow.GetLinkedAddress(userID)
	if err != nil {
		h.logger.Error("Failed to get linked address", "error", err, "user_id", userID)
		h.followUpError(s, i, "Failed to check linked address.")
		return
	}

	// 2. Check if Discord ID has a linked address
	if linkedAddress == "" {
		embed := &discordgo.MessageEmbed{
			Title:       "No Linked Address",
			Description: "❌ Your Discord account is not linked to any gno.land address. There's nothing to unlink.",
			Color:       0xff0000,
		}

		_, err = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Embeds: &[]*discordgo.MessageEmbed{embed},
		})
		if err != nil {
			h.logger.Error("Failed to edit response", "error", err, "user_id", userID)
		}
		return
	}

	// 3. Generate unlink claim
	claim, err := h.userLinkingFlow.GenerateUnlinkClaim(userID, linkedAddress)
	if err != nil {
		h.logger.Error("Failed to generate unlink claim", "error", err, "user_id", userID, "address", linkedAddress)
		h.followUpError(s, i, "Failed to generate unlink claim. Please try again.")
		return
	}

	// Create response with claim and URL
	claimURL := h.userLinkingFlow.GetClaimURL(claim)
	embed := &discordgo.MessageEmbed{
		Title:       "Unlink Your Account",
		Description: fmt.Sprintf("Ready to unlink your Discord account from `%s`", linkedAddress),
		Color:       0xff9900, // Orange color for unlink
	}

	// Add button to claim on gno.land
	components := []discordgo.MessageComponent{
		discordgo.ActionsRow{
			Components: []discordgo.MessageComponent{
				discordgo.Button{
					Label: "Unlink on gno.land",
					Style: discordgo.LinkButton,
					URL:   claimURL,
					Emoji: &discordgo.ComponentEmoji{
						Name: "🔓",
					},
				},
			},
		},
	}

	_, err = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds:     &[]*discordgo.MessageEmbed{embed},
		Components: &components,
	})
	if err != nil {
		h.logger.Error("Failed to edit response", "error", err, "user_id", userID)
	}
}

func (h *InteractionHandlers) handleUnlinkRoleCommand(s *discordgo.Session, i *discordgo.InteractionCreate, options []*discordgo.ApplicationCommandInteractionDataOption) {
	// Check role admin permissions (for realm role management)
	userID := i.Member.User.ID
	isRoleAdmin, err := h.hasRoleAdminPermission(s, i.GuildID, userID)
	if err != nil || !isRoleAdmin {
		h.respondError(s, i, "You need gno.land admin permissions to unlink realm roles. Contact a server admin to get the configured admin role.")
		return
	}

	roleName := options[0].StringValue()
	realmPath := options[1].StringValue()

	// Defer response to prevent timeout
	err = s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	})
	if err != nil {
		h.logger.Error("Failed to defer response", "error", err, "user_id", userID)
		return
	}

	// 1. Check if the role mapping exists
	roleMapping, err := h.roleLinkingFlow.GetLinkedRole(realmPath, roleName, i.GuildID)
	if err != nil {
		h.logger.Error("Failed to get linked role", "error", err, "role_name", roleName, "realm_path", realmPath)
		// If the error is "role not found", show appropriate message
		embed := &discordgo.MessageEmbed{
			Title:       "Role Not Linked",
			Description: fmt.Sprintf("❌ Realm role `%s` at `%s` is not linked to any Discord role. There's nothing to unlink.", roleName, realmPath),
			Color:       0xff0000,
		}

		_, err = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Embeds: &[]*discordgo.MessageEmbed{embed},
		})
		if err != nil {
			h.logger.Error("Failed to edit response", "error", err, "user_id", userID)
		}
		return
	}

	// 2. Additional check if role mapping is nil (defensive programming)
	if roleMapping == nil {
		embed := &discordgo.MessageEmbed{
			Title:       "Role Not Linked",
			Description: fmt.Sprintf("❌ Realm role `%s` at `%s` is not linked to any Discord role. There's nothing to unlink.", roleName, realmPath),
			Color:       0xff0000,
		}

		_, err = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Embeds: &[]*discordgo.MessageEmbed{embed},
		})
		if err != nil {
			h.logger.Error("Failed to edit response", "error", err, "user_id", userID)
		}
		return
	}

	// 3. Generate unlink claim
	claim, err := h.roleLinkingFlow.GenerateUnlinkClaim(userID, i.GuildID, roleMapping.PlatformRole.ID, roleName, realmPath)
	if err != nil {
		h.logger.Error("Failed to generate role unlink claim", "error", err, "user_id", userID, "role_name", roleName, "realm_path", realmPath)
		h.followUpError(s, i, "Failed to generate unlink claim: "+err.Error())
		return
	}

	// Create response with claim and URL
	claimURL := h.roleLinkingFlow.GetClaimURL(claim)
	embed := &discordgo.MessageEmbed{
		Title:       "Unlink Role",
		Description: fmt.Sprintf("Ready to unlink Discord role `%s` from realm role `%s` at `%s`", roleMapping.PlatformRole.Name, roleName, realmPath),
		Color:       0xff9900, // Orange color for unlink
	}

	// Add button to claim on gno.land
	components := []discordgo.MessageComponent{
		discordgo.ActionsRow{
			Components: []discordgo.MessageComponent{
				discordgo.Button{
					Label: "Unlink on gno.land",
					Style: discordgo.LinkButton,
					URL:   claimURL,
					Emoji: &discordgo.ComponentEmoji{
						Name: "🔓",
					},
				},
			},
		},
	}

	_, err = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds:     &[]*discordgo.MessageEmbed{embed},
		Components: &components,
	})
	if err != nil {
		h.logger.Error("Failed to edit response", "error", err, "user_id", userID)
	}
}

func (h *InteractionHandlers) handleHelpCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
	embed := &discordgo.MessageEmbed{
		Title:       "GnoLinker Help",
		Description: "Link your Discord account to gno.land and sync your realm roles automatically!",
		Fields: []*discordgo.MessageEmbedField{
			{
				Name: "👤 User Commands",
				Value: "`/gnolinker link <address>` - Link your Discord to a gno.land address\n" +
					"`/gnolinker unlink` - Unlink your Discord from your gno.land address\n" +
					"`/gnolinker status` - Show your linking status and roles",
			},
			{
				Name: "⚙️ Admin Commands",
				Value: "`/gnolinker admin info` - Show bot configuration and managed roles\n" +
					"`/gnolinker admin link-role <role> <realm>` - Link realm role to Discord role\n" +
					"`/gnolinker admin unlink-role <role> <realm>` - Unlink realm role from Discord role\n" +
					"`/gnolinker admin list-roles` - List all linked roles across all realms\n" +
					"`/gnolinker admin check-orphans` - Find orphaned roles (deleted or unlinked)",
			},
			{
				Name: "🔑 Permission Types",
				Value: "**Gno.land Admin**: Requires configured admin role for realm management\n" +
					"**Discord Admin**: Requires Administrator permission or server owner",
			},
			{
				Name: "ℹ️ How it works",
				Value: "1. Link your Discord to gno.land address\n" +
					"2. Gno.land admin links realm roles to Discord roles\n" +
					"3. Roles sync automatically when you link and periodically thereafter",
			},
			{
				Name: "✨ What's New",
				Value: "• Automatic role syncing - no manual sync needed!\n" +
					"• Use `/gnolinker status` to see all your roles\n" +
					"• Role management moved to admin commands for clarity\n" +
					"• Admin info now shows all managed role mappings",
			},
		},
		Color: 0x5865F2,
		Footer: &discordgo.MessageEmbedFooter{
			Text: "All responses are private to you • Need help? Contact an admin!",
		},
	}

	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds: []*discordgo.MessageEmbed{embed},
			Flags:  discordgo.MessageFlagsEphemeral,
		},
	}); err != nil {
		h.logger.Error("Failed to respond to interaction", "error", err)
	}
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
	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Flags: discordgo.MessageFlagsEphemeral,
		},
	}); err != nil {
		h.logger.Error("Failed to defer interaction response", "error", err)
		return
	}

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

	if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds:     &[]*discordgo.MessageEmbed{embed},
		Components: &components,
	}); err != nil {
		h.logger.Error("Failed to edit interaction response", "error", err)
	}
}

func (h *InteractionHandlers) handleStatusCommand(s *discordgo.Session, i *discordgo.InteractionCreate) {
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

	// Get linked address
	linkedAddress, err := h.userLinkingFlow.GetLinkedAddress(userID)
	if err != nil {
		h.logger.Error("Failed to get linked address", "error", err, "user_id", userID)
		h.followUpError(s, i, "Failed to check linked address.")
		return
	}

	// Create embed for status
	embed := &discordgo.MessageEmbed{
		Title:  "Your GnoLinker Status",
		Color:  0x5865F2,
		Fields: []*discordgo.MessageEmbedField{},
	}

	// Show linked address status
	if linkedAddress == "" {
		embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
			Name:   "🔗 Linked Address",
			Value:  "❌ Not linked to any gno.land address",
			Inline: false,
		})
		embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
			Name:   "ℹ️ How to Link",
			Value:  "Use `/gnolinker link address <your-address>` to link your account",
			Inline: false,
		})
	} else {
		embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
			Name:   "🔗 Linked Address",
			Value:  fmt.Sprintf("✅ `%s`", linkedAddress),
			Inline: false,
		})

		// Get all realm roles for this address
		allRoles := []string{}
		allDiscordRoles := []string{}

		// Get all realms we have role mappings for
		guildID := i.GuildID
		roleMappings, err := h.roleLinkingFlow.ListAllRolesByGuild(guildID)
		if err != nil {
			h.logger.Error("Failed to get role mappings", "error", err)
		} else {
			// Group by realm
			realmRoles := make(map[string][]string)
			for _, mapping := range roleMappings {
				// Check if user has this role
				hasRole, err := h.roleLinkingFlow.HasRealmRole(mapping.RealmPath, mapping.RealmRoleName, linkedAddress)
				if err != nil {
					h.logger.Error("Failed to check user role", "error", err, "realm", mapping.RealmPath, "role", mapping.RealmRoleName)
					continue
				}
				if hasRole {
					realmRoles[mapping.RealmPath] = append(realmRoles[mapping.RealmPath], mapping.RealmRoleName)
					allDiscordRoles = append(allDiscordRoles, fmt.Sprintf("<@&%s>", mapping.PlatformRole.ID))
				}
			}

			// Build roles display
			for realm, roles := range realmRoles {
				for _, role := range roles {
					allRoles = append(allRoles, fmt.Sprintf("`%s` @ `%s`", role, realm))
				}
			}
		}

		// Show realm roles
		if len(allRoles) > 0 {
			embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
				Name:   "🎭 Your Realm Roles",
				Value:  strings.Join(allRoles, "\n"),
				Inline: false,
			})
			embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
				Name:   "🏷️ Discord Roles Assigned",
				Value:  strings.Join(allDiscordRoles, " "),
				Inline: false,
			})
		} else {
			embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
				Name:   "🎭 Your Realm Roles",
				Value:  "No realm roles found",
				Inline: false,
			})
		}

		// Add last sync info
		embed.Fields = append(embed.Fields, &discordgo.MessageEmbedField{
			Name:   "🔄 Sync Status",
			Value:  "Roles are automatically synced when you link your account and periodically thereafter",
			Inline: false,
		})
	}

	// Send response
	if _, err = s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Embeds: &[]*discordgo.MessageEmbed{embed},
	}); err != nil {
		h.logger.Error("Failed to edit response", "error", err, "user_id", userID)
	}
}

func (h *InteractionHandlers) handleComponent(s *discordgo.Session, i *discordgo.InteractionCreate) {
	customID := i.MessageComponentData().CustomID

	if customID == "cancel_link" {
		if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
			Type: discordgo.InteractionResponseUpdateMessage,
			Data: &discordgo.InteractionResponseData{
				Content:    "❌ Operation cancelled.",
				Components: []discordgo.MessageComponent{},
				Embeds:     []*discordgo.MessageEmbed{},
			},
		}); err != nil {
			h.logger.Error("Failed to respond to interaction", "error", err)
		}
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
		if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
			Type: discordgo.InteractionResponseUpdateMessage,
			Data: &discordgo.InteractionResponseData{
				Content:    "❌ Invalid parameters.",
				Components: []discordgo.MessageComponent{},
				Embeds:     []*discordgo.MessageEmbed{},
			},
		}); err != nil {
			h.logger.Error("Failed to respond to interaction", "error", err)
		}
		return
	}

	roleName := parts[0]
	realmPath := parts[1]
	userID := i.Member.User.ID

	// Update to show processing
	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseUpdateMessage,
		Data: &discordgo.InteractionResponseData{
			Content:    "⏳ Creating role link...",
			Components: []discordgo.MessageComponent{},
			Embeds:     []*discordgo.MessageEmbed{},
		},
	}); err != nil {
		h.logger.Error("Failed to respond to interaction", "error", err)
		return
	}

	// Create or get the Discord role using safe role creation
	discordRoleName := roleName + "-" + realmPath
	platformRole, err := h.getOrCreateRole(s, i.GuildID, discordRoleName)
	if err != nil {
		h.logger.Error("Failed to create role", "error", err, "discord_role_name", discordRoleName)
		if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Content: &[]string{"❌ Failed to create Discord role."}[0],
		}); err != nil {
			h.logger.Error("Failed to edit interaction response", "error", err)
		}
		return
	}

	// Generate claim
	claim, err := h.roleLinkingFlow.GenerateClaim(userID, i.GuildID, platformRole.ID, roleName, realmPath)
	if err != nil {
		h.logger.Error("Failed to generate role claim", "error", err, "user_id", userID, "role_name", roleName, "realm_path", realmPath)
		if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
			Content: &[]string{"❌ Failed to generate claim."}[0],
		}); err != nil {
			h.logger.Error("Failed to edit interaction response", "error", err)
		}
		return
	}

	// Create response
	claimURL := h.roleLinkingFlow.GetClaimURL(claim)
	embed := &discordgo.MessageEmbed{
		Title:       "Role Link Created",
		Description: fmt.Sprintf("Ready to link Discord role `%s` to realm role `%s` at `%s`", platformRole.Name, roleName, realmPath),
		Color:       0x00ff00,
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

	if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Content:    &[]string{""}[0],
		Embeds:     &[]*discordgo.MessageEmbed{embed},
		Components: &components,
	}); err != nil {
		h.logger.Error("Failed to edit interaction response", "error", err)
	}
}

// Helper functions

func (h *InteractionHandlers) respondError(s *discordgo.Session, i *discordgo.InteractionCreate, message string) {
	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Content: fmt.Sprintf("❌ %s", message),
			Flags:   discordgo.MessageFlagsEphemeral,
		},
	}); err != nil {
		h.logger.Error("Failed to respond with error message", "error", err, "message", message)
	}
}

func (h *InteractionHandlers) followUpError(s *discordgo.Session, i *discordgo.InteractionCreate, message string) {
	if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{
		Content: &message,
	}); err != nil {
		h.logger.Error("Failed to edit interaction response with error", "error", err, "message", message)
	}
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

	// Role mappings info
	roleMappings, err := h.roleLinkingFlow.ListAllRolesByGuild(i.GuildID)
	if err != nil {
		h.logger.Error("Failed to get role mappings", "error", err)
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "🎭 Managed Roles",
			Value:  "Failed to retrieve role mappings",
			Inline: false,
		})
	} else if len(roleMappings) == 0 {
		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   "🎭 Managed Roles",
			Value:  "No realm roles linked yet",
			Inline: false,
		})
	} else {
		// Group role mappings by realm
		realmMappings := make(map[string][]*core.RoleMapping)
		for _, mapping := range roleMappings {
			realmMappings[mapping.RealmPath] = append(realmMappings[mapping.RealmPath], mapping)
		}

		// Build role mappings display
		var roleDisplay strings.Builder
		for realm, mappings := range realmMappings {
			roleDisplay.WriteString(fmt.Sprintf("**%s**\n", realm))
			for _, mapping := range mappings {
				roleDisplay.WriteString(fmt.Sprintf("• `%s` → <@&%s>\n", mapping.RealmRoleName, mapping.PlatformRole.ID))
			}
			roleDisplay.WriteString("\n")
		}

		fields = append(fields, &discordgo.MessageEmbedField{
			Name:   fmt.Sprintf("🎭 Managed Roles (%d total)", len(roleMappings)),
			Value:  roleDisplay.String(),
			Inline: false,
		})
	}

	embed := &discordgo.MessageEmbed{
		Title:       "Bot Configuration",
		Description: "Current bot configuration for this guild:",
		Fields:      fields,
		Color:       0x5865F2,
	}

	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds: []*discordgo.MessageEmbed{embed},
			Flags:  discordgo.MessageFlagsEphemeral,
		},
	}); err != nil {
		h.logger.Error("Failed to respond to interaction", "error", err)
	}
}
