package events

import (
	"context"
	"fmt"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/storage"
	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms"
	"github.com/bwmarrin/discordgo"
)

type EventHandlers struct {
	platform          platforms.Platform
	configManager     *config.ConfigManager
	session           *discordgo.Session
	logger            core.Logger
	userLinkingFlow   workflows.UserLinkingWorkflow
	roleLinkingFlow   workflows.RoleLinkingWorkflow
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

// ProcessPresenceAwareVerification implements the core presence-aware verification logic
func (eh *EventHandlers) ProcessPresenceAwareVerification(ctx context.Context, guildID string, state *storage.GuildQueryState) error {
	eh.logger.Info("Starting presence-aware verification", "guild_id", guildID)

	// Get all Discord members in this guild
	members, err := eh.session.GuildMembers(guildID, "", 1000)
	if err != nil {
		return fmt.Errorf("failed to get guild members: %w", err)
	}

	eh.logger.Info("Retrieved guild members for verification", 
		"guild_id", guildID, 
		"member_count", len(members),
	)

	// Get presence priority state
	presencePriority := eh.getPresencePriorityFromState(state)
	
	// Process users by priority
	totalProcessed := 0
	
	// 1. Process high priority users (online/active)
	processed, err := eh.processUsersByPriority(ctx, guildID, members, presencePriority["high"], "high")
	if err != nil {
		eh.logger.Error("Failed to process high priority users", "guild_id", guildID, "error", err)
	} else {
		totalProcessed += processed
		eh.logger.Info("Processed high priority users", "guild_id", guildID, "count", processed)
	}
	
	// 2. Process medium priority users (recently active) - up to 10 more
	if totalProcessed < 20 {
		remaining := 20 - totalProcessed
		processed, err := eh.processUsersByPriority(ctx, guildID, members, presencePriority["medium"][:min(remaining, len(presencePriority["medium"]))], "medium")
		if err != nil {
			eh.logger.Error("Failed to process medium priority users", "guild_id", guildID, "error", err)
		} else {
			totalProcessed += processed
			eh.logger.Info("Processed medium priority users", "guild_id", guildID, "count", processed)
		}
	}
	
	// 3. Process low priority users (incremental batch) - remaining capacity
	if totalProcessed < 20 {
		remaining := 20 - totalProcessed
		processed, err := eh.processIncrementalBatch(ctx, guildID, members, state, remaining)
		if err != nil {
			eh.logger.Error("Failed to process incremental batch", "guild_id", guildID, "error", err)
		} else {
			totalProcessed += processed
			eh.logger.Info("Processed incremental batch", "guild_id", guildID, "count", processed)
		}
	}

	eh.logger.Info("Completed presence-aware verification", 
		"guild_id", guildID, 
		"total_processed", totalProcessed,
	)

	return nil
}

// processUsersByPriority processes a specific set of users by priority level
func (eh *EventHandlers) processUsersByPriority(ctx context.Context, guildID string, allMembers []*discordgo.Member, userIDs []string, priority string) (int, error) {
	processed := 0
	
	for _, userID := range userIDs {
		// Find the member in the guild
		var member *discordgo.Member
		for _, m := range allMembers {
			if m.User.ID == userID {
				member = m
				break
			}
		}
		
		if member == nil {
			eh.logger.Debug("Priority user not found in guild", 
				"guild_id", guildID, 
				"user_id", userID,
				"priority", priority,
			)
			continue
		}
		
		// Process this user's role sync
		if err := eh.processUserRoleSync(ctx, guildID, member); err != nil {
			eh.logger.Error("Failed to sync roles for priority user", 
				"guild_id", guildID, 
				"user_id", userID,
				"priority", priority,
				"error", err,
			)
			continue
		}
		
		processed++
		
		// Check context for cancellation
		if ctx.Err() != nil {
			return processed, ctx.Err()
		}
	}
	
	return processed, nil
}

// processIncrementalBatch processes users in incremental batches for low priority
func (eh *EventHandlers) processIncrementalBatch(ctx context.Context, guildID string, members []*discordgo.Member, state *storage.GuildQueryState, maxUsers int) (int, error) {
	// Get last processed index
	lastUserIndex, _ := state.GetStateInt64("last_user_index")
	if lastUserIndex < 0 {
		lastUserIndex = 0
	}
	
	totalMembers := int64(len(members))
	processed := 0
	currentIndex := lastUserIndex
	
	eh.logger.Debug("Starting incremental batch processing", 
		"guild_id", guildID,
		"last_index", lastUserIndex,
		"total_members", totalMembers,
		"max_users", maxUsers,
	)
	
	for processed < maxUsers && currentIndex < totalMembers {
		member := members[currentIndex]
		
		// Process this user's role sync
		if err := eh.processUserRoleSync(ctx, guildID, member); err != nil {
			eh.logger.Error("Failed to sync roles for incremental user", 
				"guild_id", guildID, 
				"user_id", member.User.ID,
				"index", currentIndex,
				"error", err,
			)
		} else {
			processed++
		}
		
		currentIndex++
		
		// Check context for cancellation
		if ctx.Err() != nil {
			break
		}
	}
	
	// Update the last processed index
	if currentIndex >= totalMembers {
		// Reset to beginning for next cycle
		state.SetState("last_user_index", int64(0))
		eh.logger.Debug("Incremental batch completed full cycle, resetting index", "guild_id", guildID)
	} else {
		state.SetState("last_user_index", currentIndex)
	}
	
	return processed, nil
}

// processUserRoleSync syncs roles for a single user
func (eh *EventHandlers) processUserRoleSync(ctx context.Context, guildID string, member *discordgo.Member) error {
	userID := member.User.ID
	
	// Get the user's linked Gno address
	gnoAddress, err := eh.userLinkingFlow.GetLinkedAddress(userID)
	if err != nil {
		eh.logger.Debug("Failed to get linked address for user", "user_id", userID, "error", err)
		return nil // Not an error - user might not have linked address
	}
	
	if gnoAddress == "" {
		eh.logger.Debug("User has no linked address", "user_id", userID)
		return nil // Skip users without linked addresses
	}
	
	// Sync realm roles for this user
	if err := eh.syncUserRealmRoles(guildID, userID, gnoAddress); err != nil {
		return fmt.Errorf("failed to sync realm roles for user %s: %w", userID, err)
	}
	
	eh.logger.Debug("Successfully synced roles for user", 
		"guild_id", guildID,
		"user_id", userID,
		"gno_address", gnoAddress,
	)
	
	return nil
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

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
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