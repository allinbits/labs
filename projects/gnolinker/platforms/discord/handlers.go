package discord

import (
	"fmt"
	"log"

	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
)

// CommandHandlers contains all workflow-based command handlers
type CommandHandlers struct {
	userLinkingFlow workflows.UserLinkingWorkflow
	roleLinkingFlow workflows.RoleLinkingWorkflow
	syncFlow        workflows.SyncWorkflow
}

// NewCommandHandlers creates command handlers with workflow dependencies
func NewCommandHandlers(
	userFlow workflows.UserLinkingWorkflow,
	roleFlow workflows.RoleLinkingWorkflow,
	syncFlow workflows.SyncWorkflow,
) *CommandHandlers {
	return &CommandHandlers{
		userLinkingFlow: userFlow,
		roleLinkingFlow: roleFlow,
		syncFlow:        syncFlow,
	}
}

// LinkHandler handles !link commands
type LinkHandler struct {
	handlers *CommandHandlers
}

func NewLinkHandler(handlers *CommandHandlers) *LinkHandler {
	return &LinkHandler{handlers: handlers}
}

func (h *LinkHandler) HandleCommand(platform platforms.Platform, message platforms.Message, command platforms.Command) error {
	if len(command.Args) < 2 {
		return platform.SendDirectMessage(message.GetAuthorID(),
			"Usage: `!link address {address}` or `!link role {roleName} {realmPath}`")
	}

	switch command.Args[0] {
	case "address":
		return h.handleLinkAddress(platform, message, command.Args[1])
	case "role":
		if len(command.Args) < 3 {
			return platform.SendDirectMessage(message.GetAuthorID(),
				"Usage: `!link role {roleName} {realmPath}`")
		}
		return h.handleLinkRole(platform, message, command.Args[1], command.Args[2])
	default:
		return platform.SendDirectMessage(message.GetAuthorID(),
			"Unknown link type. Use `address` or `role`.")
	}
}

func (h *LinkHandler) handleLinkAddress(platform platforms.Platform, message platforms.Message, address string) error {
	userID := message.GetAuthorID()

	// Generate claim
	claim, err := h.handlers.userLinkingFlow.GenerateClaim(userID, address)
	if err != nil {
		log.Printf("Failed to generate user claim: %v", err)
		return platform.SendDirectMessage(userID, "Failed to generate claim. Please try again.")
	}

	// Create response with claim and URL
	claimURL := h.handlers.userLinkingFlow.GetClaimURL(claim)
	response := fmt.Sprintf("Here's your signed claim to link your Discord account to gno.land:\n```\n%s\n```\n[Claim your link on gno.land](%s)",
		claim.Signature, claimURL)

	return platform.SendDirectMessage(userID, response)
}

func (h *LinkHandler) handleLinkRole(platform platforms.Platform, message platforms.Message, roleName, realmPath string) error {
	userID := message.GetAuthorID()

	// Check if user is admin
	isAdmin, err := platform.IsAdmin(userID)
	if err != nil {
		log.Printf("Failed to check admin status: %v", err)
		return platform.SendDirectMessage(userID, "Failed to verify permissions.")
	}

	if !isAdmin {
		return platform.SendDirectMessage(userID, "You need admin role to link realm roles.")
	}

	// Create or get the Discord role
	discordRoleName := roleName + "-" + realmPath
	platformRole, err := platform.GetOrCreateRole(discordRoleName)
	if err != nil {
		log.Printf("Failed to create/get role: %v", err)
		return platform.SendDirectMessage(userID, "Failed to create Discord role.")
	}

	// Generate claim
	claim, err := h.handlers.roleLinkingFlow.GenerateClaim(userID, platform.GetServerID(), platformRole.ID, roleName, realmPath)
	if err != nil {
		log.Printf("Failed to generate role claim: %v", err)
		return platform.SendDirectMessage(userID, "Failed to generate claim: "+err.Error())
	}

	// Create response
	claimURL := h.handlers.roleLinkingFlow.GetClaimURL(claim)
	response := fmt.Sprintf("Here's your signed claim to link Discord role to gno.land:\n```\n%s\n```\n[Claim your link on gno.land](%s)",
		claim.Signature, claimURL)

	return platform.SendDirectMessage(userID, response)
}

// VerifyHandler handles !verify commands
type VerifyHandler struct {
	handlers *CommandHandlers
}

func NewVerifyHandler(handlers *CommandHandlers) *VerifyHandler {
	return &VerifyHandler{handlers: handlers}
}

func (h *VerifyHandler) HandleCommand(platform platforms.Platform, message platforms.Message, command platforms.Command) error {
	if len(command.Args) < 1 {
		return platform.SendDirectMessage(message.GetAuthorID(),
			"Usage: `!verify address` or `!verify role {roleName} {realmPath}`")
	}

	switch command.Args[0] {
	case "address":
		return h.handleVerifyAddress(platform, message)
	case "role":
		if len(command.Args) < 3 {
			return platform.SendDirectMessage(message.GetAuthorID(),
				"Usage: `!verify role {roleName} {realmPath}`")
		}
		return h.handleVerifyRole(platform, message, command.Args[1], command.Args[2])
	default:
		return platform.SendDirectMessage(message.GetAuthorID(),
			"Unknown verify type. Use `address` or `role`.")
	}
}

func (h *VerifyHandler) handleVerifyAddress(platform platforms.Platform, message platforms.Message) error {
	userID := message.GetAuthorID()

	// Get linked address
	address, err := h.handlers.userLinkingFlow.GetLinkedAddress(userID)
	if err != nil {
		log.Printf("Failed to get linked address: %v", err)
		return platform.SendDirectMessage(userID, "Failed to check linked address.")
	}

	// Cast to DiscordPlatform to access verified role methods
	discordPlatform, ok := platform.(*DiscordPlatform)
	if !ok {
		return platform.SendDirectMessage(userID, "Platform error.")
	}

	if address == "" {
		discordPlatform.RemoveVerifiedRole(userID)
		return platform.SendDirectMessage(userID, "No linked address found.")
	}

	discordPlatform.AddVerifiedRole(userID)
	return platform.SendDirectMessage(userID, "Your ID is linked to gno address: "+address)
}

func (h *VerifyHandler) handleVerifyRole(platform platforms.Platform, message platforms.Message, roleName, realmPath string) error {
	userID := message.GetAuthorID()

	// Get linked role
	roleMapping, err := h.handlers.roleLinkingFlow.GetLinkedRole(realmPath, roleName, platform.GetServerID())
	if err != nil {
		log.Printf("Failed to get linked role: %v", err)
		return platform.SendDirectMessage(userID, "Failed to check linked role.")
	}
	fmt.Println("Role mapping:", roleMapping)

	// Get platform role details
	platformRole, err := platform.GetRoleByID(roleMapping.PlatformRole.ID)
	if err != nil {
		log.Printf("Failed to get platform role: %v", err)
		return platform.SendDirectMessage(userID, "Discord role not found.")
	}
	fmt.Println("Platform role:", platformRole)

	// Check if user is member of the realm role
	statuses, err := h.handlers.syncFlow.SyncUserRoles(userID, realmPath)
	if err != nil {
		log.Printf("Failed to sync user roles: %v", err)
		return platform.SendDirectMessage(userID, "Failed to check role membership.")
	}
	fmt.Println("Sync statuses:", statuses)

	// Find the specific role in the statuses
	var isMember bool
	for _, status := range statuses {
		if status.RoleMapping.RealmRoleName == roleName {
			isMember = status.IsMember

			// Update Discord role
			if isMember {
				platform.AddRole(userID, platformRole.ID)
			} else {
				platform.RemoveRole(userID, platformRole.ID)
			}
			break
		}
	}

	membershipMessage := " but you are not a member."
	if isMember {
		membershipMessage = " and you are a member."
	}

	response := fmt.Sprintf("The realm role `%s` is linked to Discord role `%s`%s",
		roleName, platformRole.Name, membershipMessage)

	return platform.SendDirectMessage(userID, response)
}

// SyncHandler handles !sync commands
type SyncHandler struct {
	handlers *CommandHandlers
}

func NewSyncHandler(handlers *CommandHandlers) *SyncHandler {
	return &SyncHandler{handlers: handlers}
}

func (h *SyncHandler) HandleCommand(platform platforms.Platform, message platforms.Message, command platforms.Command) error {
	if len(command.Args) < 2 {
		return platform.SendDirectMessage(message.GetAuthorID(),
			"Usage: `!sync roles {realmPath}` or `!sync roles {realmPath} {userID}`")
	}

	if command.Args[0] != "roles" {
		return platform.SendDirectMessage(message.GetAuthorID(),
			"Currently only `!sync roles` is supported.")
	}

	realmPath := command.Args[1]
	targetUserID := message.GetAuthorID()

	// If a third argument is provided, it's a user ID (admin only)
	if len(command.Args) > 2 {
		isAdmin, err := platform.IsAdmin(message.GetAuthorID())
		if err != nil || !isAdmin {
			return platform.SendDirectMessage(message.GetAuthorID(),
				"You need admin role to sync other users' roles.")
		}
		targetUserID = command.Args[2]
	}

	// Sync roles
	statuses, err := h.handlers.syncFlow.SyncUserRoles(targetUserID, realmPath)
	if err != nil {
		log.Printf("Failed to sync user roles: %v", err)
		return platform.SendDirectMessage(message.GetAuthorID(),
			"Failed to sync roles: "+err.Error())
	}

	// Update Discord roles and build response
	response := fmt.Sprintf("Sync status for realm: %s\n", realmPath)
	for _, status := range statuses {
		// Get platform role details
		platformRole, err := platform.GetRoleByID(status.RoleMapping.PlatformRole.ID)
		if err != nil {
			log.Printf("Failed to get platform role: %v", err)
			continue
		}

		// Update Discord role
		if status.IsMember {
			platform.AddRole(targetUserID, platformRole.ID)
		} else {
			platform.RemoveRole(targetUserID, platformRole.ID)
		}

		response += fmt.Sprintf("• %s: %v (Discord: %s)\n",
			status.RoleMapping.RealmRoleName, status.IsMember, platformRole.Name)
	}

	return platform.SendDirectMessage(message.GetAuthorID(), response)
}

// HelpHandler handles !help commands
type HelpHandler struct{}

func NewHelpHandler() *HelpHandler {
	return &HelpHandler{}
}

func (h *HelpHandler) HandleCommand(platform platforms.Platform, message platforms.Message, command platforms.Command) error {
	help := `**Available Commands:**

**!link address {address}**
Generate a claim to link your Discord ID to your gno address.

**!link role {roleName} {realmPath}**
Generate a claim to link a realm role to a Discord role (Admin only).

**!verify address**
Verify that your Discord ID is linked to a gno address.

**!verify role {roleName} {realmPath}**
Verify role linking and update your Discord role membership.

**!sync roles {realmPath}**
Synchronize all registered realm roles for your account.

**!sync roles {realmPath} {userID}**
Synchronize roles for another user (Admin only).

**!help**
Show this help message.`

	return platform.SendDirectMessage(message.GetAuthorID(), help)
}
