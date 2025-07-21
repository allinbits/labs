package events

import (
	"context"
	"fmt"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
	"github.com/bwmarrin/discordgo"
)

type EventHandlers struct {
	platform        platforms.Platform
	configManager   *config.ConfigManager
	session         *discordgo.Session
	logger          core.Logger
	userLinkingFlow workflows.UserLinkingWorkflow
	roleLinkingFlow workflows.RoleLinkingWorkflow
}

func NewEventHandlers(platform platforms.Platform, configManager *config.ConfigManager, session *discordgo.Session, logger core.Logger, userLinkingFlow workflows.UserLinkingWorkflow, roleLinkingFlow workflows.RoleLinkingWorkflow) *EventHandlers {
	return &EventHandlers{
		platform:        platform,
		configManager:   configManager,
		session:         session,
		logger:          logger,
		userLinkingFlow: userLinkingFlow,
		roleLinkingFlow: roleLinkingFlow,
	}
}

func (eh *EventHandlers) HandleUserLinked(event Event) error {
	if event.UserLinked == nil {
		return fmt.Errorf("UserLinked event data is nil")
	}

	userLinked := event.UserLinked
	eh.logger.Info("Processing UserLinked event",
		"discord_id", userLinked.DiscordID,
		"gno_address", userLinked.Address,
		"tx_hash", event.TransactionHash,
		"block_height", event.BlockHeight,
	)

	guilds, err := eh.getUserGuilds(userLinked.DiscordID)
	if err != nil {
		eh.logger.Error("Failed to get user guilds", "discord_id", userLinked.DiscordID, "error", err)
		return fmt.Errorf("failed to get user guilds: %w", err)
	}

	eh.logger.Info("Found user in guilds", "discord_id", userLinked.DiscordID, "guild_count", len(guilds))
	for i, guild := range guilds {
		eh.logger.Info("User guild", "index", i, "guild_id", guild.ID, "guild_name", guild.Name)
	}

	for _, guild := range guilds {
		if err := eh.addVerifiedRoleToUser(guild.ID, userLinked.DiscordID); err != nil {
			eh.logger.Error("Failed to add verified role to user",
				"guild_id", guild.ID,
				"discord_id", userLinked.DiscordID,
				"error", err,
			)
			continue
		}

		eh.logger.Info("Added verified role to user",
			"guild_id", guild.ID,
			"discord_id", userLinked.DiscordID,
		)

		// NEW: Immediately sync all realm roles for this user
		if err := eh.syncUserRealmRoles(guild.ID, userLinked.DiscordID, userLinked.Address); err != nil {
			eh.logger.Error("Failed to sync realm roles for newly linked user",
				"guild_id", guild.ID,
				"discord_id", userLinked.DiscordID,
				"gno_address", userLinked.Address,
				"error", err,
			)
			// Continue with other guilds even if realm role sync fails
		} else {
			eh.logger.Info("Successfully synced realm roles for newly linked user",
				"guild_id", guild.ID,
				"discord_id", userLinked.DiscordID,
				"gno_address", userLinked.Address,
			)
		}
	}

	return nil
}

func (eh *EventHandlers) HandleUserUnlinked(event Event) error {
	if event.UserUnlinked == nil {
		return fmt.Errorf("UserUnlinked event data is nil")
	}

	userUnlinked := event.UserUnlinked
	eh.logger.Info("Processing UserUnlinked event",
		"discord_id", userUnlinked.DiscordID,
		"gno_address", userUnlinked.Address,
		"triggered_by", userUnlinked.TriggeredBy,
		"tx_hash", event.TransactionHash,
		"block_height", event.BlockHeight,
	)

	guilds, err := eh.getUserGuilds(userUnlinked.DiscordID)
	if err != nil {
		eh.logger.Error("Failed to get user guilds", "discord_id", userUnlinked.DiscordID, "error", err)
		return fmt.Errorf("failed to get user guilds: %w", err)
	}

	for _, guild := range guilds {
		if err := eh.removeVerifiedRoleFromUser(guild.ID, userUnlinked.DiscordID); err != nil {
			eh.logger.Error("Failed to remove verified role from user",
				"guild_id", guild.ID,
				"discord_id", userUnlinked.DiscordID,
				"error", err,
			)
			continue
		}

		eh.logger.Info("Removed verified role from user",
			"guild_id", guild.ID,
			"discord_id", userUnlinked.DiscordID,
		)

		// NEW: Remove all realm-based Discord roles from this user
		if err := eh.removeAllRealmRoles(guild.ID, userUnlinked.DiscordID); err != nil {
			eh.logger.Error("Failed to remove realm roles from unlinked user",
				"guild_id", guild.ID,
				"discord_id", userUnlinked.DiscordID,
				"error", err,
			)
			// Continue with other guilds even if realm role removal fails
		} else {
			eh.logger.Info("Successfully removed all realm roles from unlinked user",
				"guild_id", guild.ID,
				"discord_id", userUnlinked.DiscordID,
			)
		}
	}

	return nil
}

func (eh *EventHandlers) getUserGuilds(userID string) ([]*discordgo.Guild, error) {
	var userGuilds []*discordgo.Guild

	for _, guild := range eh.session.State.Guilds {
		member, err := eh.session.GuildMember(guild.ID, userID)
		if err != nil {
			continue
		}

		if member != nil {
			userGuilds = append(userGuilds, guild)
		}
	}

	return userGuilds, nil
}

func (eh *EventHandlers) addVerifiedRoleToUser(guildID, userID string) error {
	eh.logger.Info("Attempting to add verified role to user", "guild_id", guildID, "user_id", userID)

	config, err := eh.configManager.GetGuildConfig(guildID)
	if err != nil {
		eh.logger.Error("Failed to get guild config", "guild_id", guildID, "error", err)
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	eh.logger.Info("Guild config retrieved", "guild_id", guildID, "verified_role_id", config.VerifiedRoleID)

	if config.VerifiedRoleID == "" {
		eh.logger.Warn("No verified role configured for guild", "guild_id", guildID)
		return nil
	}

	hasRole, err := eh.platform.HasRole(guildID, userID, config.VerifiedRoleID)
	if err != nil {
		eh.logger.Error("Failed to check if user has role", "guild_id", guildID, "user_id", userID, "role_id", config.VerifiedRoleID, "error", err)
		return fmt.Errorf("failed to check if user has role: %w", err)
	}

	eh.logger.Info("Role check result", "guild_id", guildID, "user_id", userID, "has_role", hasRole)

	if hasRole {
		eh.logger.Debug("User already has verified role", "guild_id", guildID, "user_id", userID)
		return nil
	}

	eh.logger.Info("Adding role to user", "guild_id", guildID, "user_id", userID, "role_id", config.VerifiedRoleID)
	err = eh.platform.AddRole(guildID, userID, config.VerifiedRoleID)
	if err != nil {
		eh.logger.Error("Failed to add role to user", "guild_id", guildID, "user_id", userID, "role_id", config.VerifiedRoleID, "error", err)
		return fmt.Errorf("failed to add role: %w", err)
	}

	eh.logger.Info("Successfully added role to user", "guild_id", guildID, "user_id", userID, "role_id", config.VerifiedRoleID)
	return nil
}

func (eh *EventHandlers) removeVerifiedRoleFromUser(guildID, userID string) error {
	config, err := eh.configManager.GetGuildConfig(guildID)
	if err != nil {
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	if config.VerifiedRoleID == "" {
		eh.logger.Warn("No verified role configured for guild", "guild_id", guildID)
		return nil
	}

	hasRole, err := eh.platform.HasRole(guildID, userID, config.VerifiedRoleID)
	if err != nil {
		return fmt.Errorf("failed to check if user has role: %w", err)
	}

	if !hasRole {
		eh.logger.Debug("User doesn't have verified role", "guild_id", guildID, "user_id", userID)
		return nil
	}

	return eh.platform.RemoveRole(guildID, userID, config.VerifiedRoleID)
}

// syncUserRealmRoles immediately syncs all realm roles for a specific user
func (eh *EventHandlers) syncUserRealmRoles(guildID, discordID, gnoAddress string) error {
	eh.logger.Info("Syncing realm roles for user",
		"guild_id", guildID,
		"discord_id", discordID,
		"gno_address", gnoAddress,
	)

	// Get guild config to determine monitored realms
	config, err := eh.configManager.GetGuildConfig(guildID)
	if err != nil {
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	// Get monitored realms from guild settings (default to empty if not set)
	monitoredRealms := eh.getMonitoredRealms(config)
	if len(monitoredRealms) == 0 {
		eh.logger.Debug("No monitored realms configured for guild", "guild_id", guildID)
		return nil
	}

	// Sync roles for each monitored realm
	for _, realmPath := range monitoredRealms {
		if err := eh.syncUserRolesByRealm(guildID, discordID, gnoAddress, realmPath); err != nil {
			eh.logger.Error("Failed to sync user roles for realm",
				"guild_id", guildID,
				"discord_id", discordID,
				"realm_path", realmPath,
				"error", err,
			)
			// Continue with other realms
		}
	}

	return nil
}

// syncUserRolesByRealm syncs roles for a user within a specific realm
func (eh *EventHandlers) syncUserRolesByRealm(guildID, discordID, gnoAddress, realmPath string) error {
	// Get all role mappings for this realm
	roleMappings, err := eh.roleLinkingFlow.ListLinkedRoles(realmPath, guildID)
	if err != nil {
		return fmt.Errorf("failed to list linked roles: %w", err)
	}

	if len(roleMappings) == 0 {
		eh.logger.Debug("No role mappings found for realm", "realm_path", realmPath, "guild_id", guildID)
		return nil
	}

	eh.logger.Info("Syncing user roles for realm",
		"realm_path", realmPath,
		"role_count", len(roleMappings),
		"discord_id", discordID,
	)

	// Check membership and sync each role
	for _, roleMapping := range roleMappings {
		hasRealmRole, err := eh.roleLinkingFlow.HasRealmRole(realmPath, roleMapping.RealmRoleName, gnoAddress)
		if err != nil {
			eh.logger.Error("Failed to check realm role membership",
				"realm_path", realmPath,
				"role_name", roleMapping.RealmRoleName,
				"gno_address", gnoAddress,
				"error", err,
			)
			continue
		}

		// Check if user currently has the Discord role
		hasDiscordRole, err := eh.platform.HasRole(guildID, discordID, roleMapping.PlatformRole.ID)
		if err != nil {
			eh.logger.Error("Failed to check Discord role",
				"discord_role_id", roleMapping.PlatformRole.ID,
				"discord_id", discordID,
				"error", err,
			)
			continue
		}

		// Sync roles based on realm membership
		if hasRealmRole && !hasDiscordRole {
			// User should have Discord role but doesn't - add it
			err = eh.platform.AddRole(guildID, discordID, roleMapping.PlatformRole.ID)
			if err != nil {
				eh.logger.Error("Failed to add Discord role",
					"discord_role_id", roleMapping.PlatformRole.ID,
					"discord_id", discordID,
					"error", err,
				)
			} else {
				eh.logger.Info("Added Discord role to user",
					"discord_role_id", roleMapping.PlatformRole.ID,
					"role_name", roleMapping.RealmRoleName,
					"discord_id", discordID,
				)
			}
		} else if !hasRealmRole && hasDiscordRole {
			// User has Discord role but shouldn't - remove it
			err = eh.platform.RemoveRole(guildID, discordID, roleMapping.PlatformRole.ID)
			if err != nil {
				eh.logger.Error("Failed to remove Discord role",
					"discord_role_id", roleMapping.PlatformRole.ID,
					"discord_id", discordID,
					"error", err,
				)
			} else {
				eh.logger.Info("Removed Discord role from user",
					"discord_role_id", roleMapping.PlatformRole.ID,
					"role_name", roleMapping.RealmRoleName,
					"discord_id", discordID,
				)
			}
		}
	}

	return nil
}

// removeAllRealmRoles removes all realm-based Discord roles from a user
func (eh *EventHandlers) removeAllRealmRoles(guildID, discordID string) error {
	eh.logger.Info("Removing all realm roles for user",
		"guild_id", guildID,
		"discord_id", discordID,
	)

	// Get guild config to determine monitored realms
	config, err := eh.configManager.GetGuildConfig(guildID)
	if err != nil {
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	// Get monitored realms from guild settings
	monitoredRealms := eh.getMonitoredRealms(config)
	if len(monitoredRealms) == 0 {
		eh.logger.Debug("No monitored realms configured for guild", "guild_id", guildID)
		return nil
	}

	// Remove roles for each monitored realm
	for _, realmPath := range monitoredRealms {
		roleMappings, err := eh.roleLinkingFlow.ListLinkedRoles(realmPath, guildID)
		if err != nil {
			eh.logger.Error("Failed to list linked roles for removal",
				"realm_path", realmPath,
				"guild_id", guildID,
				"error", err,
			)
			continue
		}

		for _, roleMapping := range roleMappings {
			hasDiscordRole, err := eh.platform.HasRole(guildID, discordID, roleMapping.PlatformRole.ID)
			if err != nil {
				eh.logger.Error("Failed to check Discord role for removal",
					"discord_role_id", roleMapping.PlatformRole.ID,
					"discord_id", discordID,
					"error", err,
				)
				continue
			}

			if hasDiscordRole {
				err = eh.platform.RemoveRole(guildID, discordID, roleMapping.PlatformRole.ID)
				if err != nil {
					eh.logger.Error("Failed to remove Discord role from unlinked user",
						"discord_role_id", roleMapping.PlatformRole.ID,
						"discord_id", discordID,
						"error", err,
					)
				} else {
					eh.logger.Info("Removed Discord role from unlinked user",
						"discord_role_id", roleMapping.PlatformRole.ID,
						"role_name", roleMapping.RealmRoleName,
						"discord_id", discordID,
					)
				}
			}
		}
	}

	return nil
}

// getMonitoredRealms returns the list of realm paths being monitored for this guild
func (eh *EventHandlers) getMonitoredRealms(config *storage.GuildConfig) []string {
	// For now, return a default set of common realms
	// TODO: Make this configurable via guild settings
	return []string{
		"gno.land/r/governance",
		"gno.land/r/demo/boards",
		"gno.land/r/demo/users",
	}
}

// ProcessTieredVerification implements tiered member verification with 4-state logic
func (eh *EventHandlers) ProcessTieredVerification(ctx context.Context, guildID string, state *storage.GuildQueryState, priority string, maxUsers int) error {
	eh.logger.Info("Starting tiered verification", "guild_id", guildID, "priority", priority, "max_users", maxUsers)

	// Get all Discord members in this guild
	members, err := eh.session.GuildMembers(guildID, "", 1000)
	if err != nil {
		return fmt.Errorf("failed to get guild members: %w", err)
	}

	eh.logger.Info("Retrieved guild members for verification",
		"guild_id", guildID,
		"priority", priority,
		"member_count", len(members),
	)

	// Get users to process based on priority
	usersToProcess := eh.getUsersByPriority(state, members, priority, maxUsers)
	totalProcessed := 0

	// Process each user with 4-state verification logic
	for _, member := range usersToProcess {
		if err := eh.processUserVerification(ctx, guildID, member); err != nil {
			eh.logger.Error("Failed to verify user",
				"guild_id", guildID,
				"user_id", member.User.ID,
				"priority", priority,
				"error", err)
			continue
		}

		totalProcessed++

		// Check context for cancellation
		if ctx.Err() != nil {
			break
		}
	}

	// Update incremental processing state for low priority
	if priority == "low" {
		eh.updateIncrementalState(state, members, totalProcessed)
	}

	eh.logger.Info("Completed tiered verification",
		"guild_id", guildID,
		"priority", priority,
		"total_processed", totalProcessed,
	)

	return nil
}

// getUsersByPriority returns users to process based on priority tier
func (eh *EventHandlers) getUsersByPriority(state *storage.GuildQueryState, allMembers []*discordgo.Member, priority string, maxUsers int) []*discordgo.Member {
	switch priority {
	case "high":
		// High priority: get all online/active users
		return eh.getHighPriorityUsers(state, allMembers)
	case "medium":
		// Medium priority: get recently active users (up to maxUsers)
		return eh.getMediumPriorityUsers(state, allMembers, maxUsers)
	case "low":
		// Low priority: get next batch of inactive users (incremental)
		return eh.getLowPriorityUsers(state, allMembers, maxUsers)
	default:
		return []*discordgo.Member{}
	}
}

// getHighPriorityUsers returns all users marked as high priority (online/active)
func (eh *EventHandlers) getHighPriorityUsers(state *storage.GuildQueryState, allMembers []*discordgo.Member) []*discordgo.Member {
	priorityData := eh.getPresencePriorityFromState(state)
	highPriorityIDs := priorityData["high"]

	var result []*discordgo.Member
	for _, member := range allMembers {
		for _, userID := range highPriorityIDs {
			if member.User.ID == userID {
				result = append(result, member)
				break
			}
		}
	}

	return result
}

// getMediumPriorityUsers returns users marked as medium priority (recently active)
func (eh *EventHandlers) getMediumPriorityUsers(state *storage.GuildQueryState, allMembers []*discordgo.Member, maxUsers int) []*discordgo.Member {
	priorityData := eh.getPresencePriorityFromState(state)
	mediumPriorityIDs := priorityData["medium"]

	var result []*discordgo.Member
	count := 0

	for _, member := range allMembers {
		if count >= maxUsers {
			break
		}
		for _, userID := range mediumPriorityIDs {
			if member.User.ID == userID {
				result = append(result, member)
				count++
				break
			}
		}
	}

	return result
}

// getLowPriorityUsers returns next batch of users for incremental processing
func (eh *EventHandlers) getLowPriorityUsers(state *storage.GuildQueryState, allMembers []*discordgo.Member, maxUsers int) []*discordgo.Member {
	// Get last processed index for incremental processing
	lastUserIndex, _ := state.GetStateInt64("last_user_index")
	if lastUserIndex < 0 {
		lastUserIndex = 0
	}

	totalMembers := int64(len(allMembers))
	var result []*discordgo.Member
	currentIndex := lastUserIndex
	count := 0

	// Get next batch of users starting from lastUserIndex
	for currentIndex < totalMembers && count < maxUsers {
		member := allMembers[currentIndex]

		// Skip users that are in high or medium priority
		if !eh.isUserInHighMediumPriority(state, member.User.ID) {
			result = append(result, member)
			count++
		}

		currentIndex++
	}

	return result
}

// isUserInHighMediumPriority checks if user is already in high or medium priority lists
func (eh *EventHandlers) isUserInHighMediumPriority(state *storage.GuildQueryState, userID string) bool {
	priorityData := eh.getPresencePriorityFromState(state)

	// Check high priority
	for _, id := range priorityData["high"] {
		if id == userID {
			return true
		}
	}

	// Check medium priority
	for _, id := range priorityData["medium"] {
		if id == userID {
			return true
		}
	}

	return false
}

// updateIncrementalState updates the incremental processing state for low priority queries
func (eh *EventHandlers) updateIncrementalState(state *storage.GuildQueryState, allMembers []*discordgo.Member, processed int) {
	// Get current index
	lastUserIndex, _ := state.GetStateInt64("last_user_index")
	if lastUserIndex < 0 {
		lastUserIndex = 0
	}

	totalMembers := int64(len(allMembers))
	newIndex := lastUserIndex + int64(processed)

	// Reset to beginning if we've processed all users
	if newIndex >= totalMembers {
		state.SetState("last_user_index", int64(0))
		eh.logger.Debug("Incremental processing completed full cycle, resetting index")
	} else {
		state.SetState("last_user_index", newIndex)
		eh.logger.Debug("Updated incremental processing index",
			"old_index", lastUserIndex,
			"new_index", newIndex,
			"processed", processed)
	}
}

// processUserVerification implements the 4-state verification logic for a single user
func (eh *EventHandlers) processUserVerification(ctx context.Context, guildID string, member *discordgo.Member) error {
	userID := member.User.ID

	// Check if user has Discord verified role
	hasVerifiedRole, err := eh.userHasVerifiedRole(guildID, userID)
	if err != nil {
		return fmt.Errorf("failed to check verified role for user %s: %w", userID, err)
	}

	// Check if user is registered in Gno realm using QEval
	gnoAddress, err := eh.userLinkingFlow.GetLinkedAddress(userID)
	if err != nil {
		eh.logger.Debug("Failed to get linked address for user", "user_id", userID, "error", err)
		// Treat as not registered if we can't query the realm
		gnoAddress = ""
	}

	isInGnoRegistry := gnoAddress != ""

	eh.logger.Debug("User verification state",
		"guild_id", guildID,
		"user_id", userID,
		"has_verified_role", hasVerifiedRole,
		"is_in_gno_registry", isInGnoRegistry,
		"gno_address", gnoAddress,
	)

	// Implement 4-state verification logic
	if hasVerifiedRole && !isInGnoRegistry {
		// State 1: Has Discord verified role + NOT in Gno registry
		// → Remove verified role + Remove from all realm roles
		return eh.handleState1_RemoveVerifiedAndRealmRoles(guildID, userID)

	} else if hasVerifiedRole && isInGnoRegistry {
		// State 2: Has Discord verified role + IS in Gno registry
		// → Keep verified role + Sync all realm roles
		return eh.handleState2_SyncRealmRoles(guildID, userID, gnoAddress)

	} else if !hasVerifiedRole && !isInGnoRegistry {
		// State 3: NO Discord verified role + NOT in Gno registry
		// → Ensure no realm roles + Exit
		return eh.handleState3_EnsureNoRealmRoles(guildID, userID)

	} else if !hasVerifiedRole && isInGnoRegistry {
		// State 4: NO Discord verified role + IS in Gno registry
		// → Add verified role + Sync all realm roles
		return eh.handleState4_AddVerifiedAndSyncRoles(guildID, userID, gnoAddress)
	}

	return nil
}

// userHasVerifiedRole checks if user has the verified Discord role
func (eh *EventHandlers) userHasVerifiedRole(guildID, userID string) (bool, error) {
	config, err := eh.configManager.GetGuildConfig(guildID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild config: %w", err)
	}

	if config.VerifiedRoleID == "" {
		return false, nil // No verified role configured
	}

	return eh.platform.HasRole(guildID, userID, config.VerifiedRoleID)
}

// handleState1_RemoveVerifiedAndRealmRoles handles State 1: Has verified role but not in Gno registry
func (eh *EventHandlers) handleState1_RemoveVerifiedAndRealmRoles(guildID, userID string) error {
	eh.logger.Info("Processing State 1: Removing verified role and realm roles",
		"guild_id", guildID, "user_id", userID)

	// Remove verified Discord role
	if err := eh.removeVerifiedRoleFromUser(guildID, userID); err != nil {
		eh.logger.Error("Failed to remove verified role",
			"guild_id", guildID, "user_id", userID, "error", err)
		// Continue to remove realm roles even if verified role removal fails
	}

	// Remove all realm-based Discord roles
	return eh.removeAllRealmRoles(guildID, userID)
}

// handleState2_SyncRealmRoles handles State 2: Has verified role and is in Gno registry
func (eh *EventHandlers) handleState2_SyncRealmRoles(guildID, userID, gnoAddress string) error {
	eh.logger.Debug("Processing State 2: Syncing realm roles",
		"guild_id", guildID, "user_id", userID, "gno_address", gnoAddress)

	// Sync realm roles for this user
	return eh.syncUserRealmRoles(guildID, userID, gnoAddress)
}

// handleState3_EnsureNoRealmRoles handles State 3: No verified role and not in Gno registry
func (eh *EventHandlers) handleState3_EnsureNoRealmRoles(guildID, userID string) error {
	eh.logger.Debug("Processing State 3: Ensuring no realm roles",
		"guild_id", guildID, "user_id", userID)

	// Remove any realm-based Discord roles (shouldn't have any, but ensure clean state)
	return eh.removeAllRealmRoles(guildID, userID)
}

// handleState4_AddVerifiedAndSyncRoles handles State 4: No verified role but is in Gno registry
func (eh *EventHandlers) handleState4_AddVerifiedAndSyncRoles(guildID, userID, gnoAddress string) error {
	eh.logger.Info("Processing State 4: Adding verified role and syncing realm roles",
		"guild_id", guildID, "user_id", userID, "gno_address", gnoAddress)

	// Add verified Discord role
	if err := eh.addVerifiedRoleToUser(guildID, userID); err != nil {
		eh.logger.Error("Failed to add verified role",
			"guild_id", guildID, "user_id", userID, "error", err)
		// Continue to sync realm roles even if verified role addition fails
	}

	// Sync realm roles for this user
	return eh.syncUserRealmRoles(guildID, userID, gnoAddress)
}

// getPresencePriorityFromState extracts presence priority data from query state
func (eh *EventHandlers) getPresencePriorityFromState(state *storage.GuildQueryState) map[string][]string {
	if priorityData, exists := state.GetState("presence_priority"); exists {
		if priorityMap, ok := priorityData.(map[string]interface{}); ok {
			result := make(map[string][]string)
			for level, users := range priorityMap {
				if userList, ok := users.([]interface{}); ok {
					strList := make([]string, 0, len(userList))
					for _, user := range userList {
						if userStr, ok := user.(string); ok {
							strList = append(strList, userStr)
						}
					}
					result[level] = strList
				}
			}
			return result
		}
	}

	// Return default empty priority state
	return map[string][]string{
		"high":   []string{},
		"medium": []string{},
		"low":    []string{},
	}
}

func (eh *EventHandlers) HandleRoleLinked(event Event) error {
	if event.RoleLinked == nil {
		return fmt.Errorf("RoleLinked event data is nil")
	}

	roleLinked := event.RoleLinked
	eh.logger.Info("Processing RoleLinked event",
		"realm_path", roleLinked.RealmPath,
		"role_name", roleLinked.RoleName,
		"discord_guild_id", roleLinked.DiscordGuildID,
		"discord_role_id", roleLinked.DiscordRoleID,
		"tx_hash", event.TransactionHash,
		"block_height", event.BlockHeight,
	)

	// For role events, we only process if the event is for this specific guild
	// Check if this guild is actually being managed by this bot instance
	found := false
	for _, guild := range eh.session.State.Guilds {
		if guild.ID == roleLinked.DiscordGuildID {
			found = true
			break
		}
	}

	if !found {
		eh.logger.Debug("RoleLinked event is for a different guild, ignoring",
			"event_guild_id", roleLinked.DiscordGuildID)
		return nil
	}

	eh.logger.Info("RoleLinked event confirmed for managed guild",
		"guild_id", roleLinked.DiscordGuildID,
		"realm_path", roleLinked.RealmPath,
		"role_name", roleLinked.RoleName,
		"discord_role_id", roleLinked.DiscordRoleID,
	)

	// Get all members with the realm role and add the Discord role
	return eh.syncRoleMembers(roleLinked.DiscordGuildID, roleLinked.RealmPath, roleLinked.RoleName, roleLinked.DiscordRoleID, true)
}

func (eh *EventHandlers) HandleRoleUnlinked(event Event) error {
	if event.RoleUnlinked == nil {
		return fmt.Errorf("RoleUnlinked event data is nil")
	}

	roleUnlinked := event.RoleUnlinked
	eh.logger.Info("Processing RoleUnlinked event",
		"realm_path", roleUnlinked.RealmPath,
		"role_name", roleUnlinked.RoleName,
		"discord_guild_id", roleUnlinked.DiscordGuildID,
		"discord_role_id", roleUnlinked.DiscordRoleID,
		"tx_hash", event.TransactionHash,
		"block_height", event.BlockHeight,
	)

	// For role events, we only process if the event is for this specific guild
	// Check if this guild is actually being managed by this bot instance
	found := false
	for _, guild := range eh.session.State.Guilds {
		if guild.ID == roleUnlinked.DiscordGuildID {
			found = true
			break
		}
	}

	if !found {
		eh.logger.Debug("RoleUnlinked event is for a different guild, ignoring",
			"event_guild_id", roleUnlinked.DiscordGuildID)
		return nil
	}

	eh.logger.Info("RoleUnlinked event confirmed for managed guild",
		"guild_id", roleUnlinked.DiscordGuildID,
		"realm_path", roleUnlinked.RealmPath,
		"role_name", roleUnlinked.RoleName,
		"discord_role_id", roleUnlinked.DiscordRoleID,
	)

	// Remove the Discord role from all members
	return eh.syncRoleMembers(roleUnlinked.DiscordGuildID, roleUnlinked.RealmPath, roleUnlinked.RoleName, roleUnlinked.DiscordRoleID, false)
}

func (eh *EventHandlers) syncRoleMembers(guildID, realmPath, roleName, discordRoleID string, shouldHaveRole bool) error {
	eh.logger.Info("Syncing role members",
		"guild_id", guildID,
		"realm_path", realmPath,
		"role_name", roleName,
		"discord_role_id", discordRoleID,
		"should_have_role", shouldHaveRole,
	)

	// Get all Discord members in this guild
	members, err := eh.session.GuildMembers(guildID, "", 1000)
	if err != nil {
		eh.logger.Error("Failed to get guild members", "guild_id", guildID, "error", err)
		return fmt.Errorf("failed to get guild members: %w", err)
	}

	eh.logger.Info("Found guild members", "guild_id", guildID, "member_count", len(members))

	for _, member := range members {
		// Get the linked Gno address for this Discord user
		gnoAddress, err := eh.userLinkingFlow.GetLinkedAddress(member.User.ID)
		if err != nil {
			eh.logger.Debug("Failed to get linked address for user", "user_id", member.User.ID, "error", err)
			continue
		}

		if gnoAddress == "" {
			eh.logger.Debug("User has no linked address", "user_id", member.User.ID)
			continue
		}

		// Check if this user has the realm role
		hasRealmRole, err := eh.roleLinkingFlow.HasRealmRole(realmPath, roleName, gnoAddress)
		if err != nil {
			eh.logger.Error("Failed to check realm role",
				"user_id", member.User.ID,
				"gno_address", gnoAddress,
				"realm_path", realmPath,
				"role_name", roleName,
				"error", err,
			)
			continue
		}

		// Check if user currently has the Discord role
		hasDiscordRole := false
		for _, roleID := range member.Roles {
			if roleID == discordRoleID {
				hasDiscordRole = true
				break
			}
		}

		eh.logger.Debug("Role sync check",
			"user_id", member.User.ID,
			"gno_address", gnoAddress,
			"has_realm_role", hasRealmRole,
			"has_discord_role", hasDiscordRole,
			"should_have_role", shouldHaveRole,
		)

		// Sync the roles
		if shouldHaveRole {
			// Role was linked - users with realm role should get Discord role
			if hasRealmRole && !hasDiscordRole {
				err = eh.platform.AddRole(guildID, member.User.ID, discordRoleID)
				if err != nil {
					eh.logger.Error("Failed to add Discord role",
						"user_id", member.User.ID,
						"discord_role_id", discordRoleID,
						"error", err,
					)
				} else {
					eh.logger.Info("Added Discord role to user",
						"user_id", member.User.ID,
						"discord_role_id", discordRoleID,
					)
				}
			}
		} else {
			// Role was unlinked - remove Discord role from all users
			if hasDiscordRole {
				err = eh.platform.RemoveRole(guildID, member.User.ID, discordRoleID)
				if err != nil {
					eh.logger.Error("Failed to remove Discord role",
						"user_id", member.User.ID,
						"discord_role_id", discordRoleID,
						"error", err,
					)
				} else {
					eh.logger.Info("Removed Discord role from user",
						"user_id", member.User.ID,
						"discord_role_id", discordRoleID,
					)
				}
			}
		}
	}

	return nil
}

// UpdateUserPresence updates the presence state for a user in a specific guild
func (eh *EventHandlers) UpdateUserPresence(guildID, userID string, isActive bool) error {
	config, err := eh.configManager.GetGuildConfig(guildID)
	if err != nil {
		return fmt.Errorf("failed to get guild config: %w", err)
	}

	// Get or create presence state for all verify queries
	queries := []string{"verify_high_priority", "verify_medium_priority", "verify_low_priority"}

	for _, queryID := range queries {
		queryState := config.EnsureQueryState(queryID, true)

		// Get current presence priority data
		priorityData := eh.getPresencePriorityFromState(queryState)

		// Update user's presence and priority
		eh.updateUserPriority(priorityData, userID, isActive)

		// Save updated priority data back to state
		queryState.SetState("presence_priority", priorityData)
		queryState.SetState("user_activity", map[string]interface{}{
			userID: map[string]interface{}{
				"last_active": time.Now().Unix(),
				"is_active":   isActive,
			},
		})
	}

	// Save the updated config
	return eh.configManager.GetStore().Set(guildID, config)
}

// updateUserPriority moves a user between priority tiers based on their activity
func (eh *EventHandlers) updateUserPriority(priorityData map[string][]string, userID string, isActive bool) {
	// Remove user from all priority levels first
	for level := range priorityData {
		priorityData[level] = eh.removeUserFromSlice(priorityData[level], userID)
	}

	// Add user to appropriate priority level
	if isActive {
		// Active users go to high priority
		priorityData["high"] = append(priorityData["high"], userID)
	} else {
		// Inactive users go to low priority
		priorityData["low"] = append(priorityData["low"], userID)
	}
}

// removeUserFromSlice removes a user ID from a slice
func (eh *EventHandlers) removeUserFromSlice(slice []string, userID string) []string {
	for i, id := range slice {
		if id == userID {
			return append(slice[:i], slice[i+1:]...)
		}
	}
	return slice
}
