# GnoLinker Discord Bot - Slash Commands Guide

## Overview

GnoLinker uses a modern slash command interface with a single `/gnolinker` command and organized subcommands. This avoids name collisions and provides a clean, discoverable interface. All responses are ephemeral (private to you) in channels.

## Command Structure

All commands are organized under `/gnolinker` with intuitive subcommand groups:

### Link Commands

- `/gnolinker link address <address>` - Link your Discord to gno.land
- `/gnolinker link role <role> <realm>` - Link realm role to Discord role (Admin)

### Verify Commands

- `/gnolinker verify address` - Check your account linking status
- `/gnolinker verify role <role> <realm>` - Check role linking status

### Sync Commands

- `/gnolinker sync roles <realm>` - Sync your realm roles
- `/gnolinker sync user <realm> <user>` - Sync another user's roles (Admin)

### Help

- `/gnolinker help` - Show all available commands

## User Commands

### `/gnolinker link address <address>`

Link your Discord account to a gno.land address.

- **Parameters:**
  - `address` (required): Your gno.land address
- **Response:** Ephemeral message with claim signature and link button
- **Side Effects:** None (claim must be submitted on gno.land)

### `/gnolinker verify address`

Verify your account linking status.

- **Response:** Ephemeral message showing linked address (if any)
- **Side Effects:** Adds/removes verified role based on linking status

### `/gnolinker sync roles <realm>`

Synchronize your realm roles with Discord roles.

- **Parameters:**
  - `realm` (required): The realm path to sync from
- **Response:** Ephemeral message showing role sync status
- **Side Effects:** Updates Discord roles based on realm membership

## Admin Commands

Admin commands require the configured admin role.

### `/gnolinker link role <role> <realm>`

Link a realm role to a Discord role (Admin only).

- **Parameters:**
  - `role` (required): The realm role name
  - `realm` (required): The realm path
- **Response:** Confirmation dialog with buttons
- **Side Effects:** Creates Discord role if it doesn't exist

### `/gnolinker verify role <role> <realm>`

Check role linking status.

- **Parameters:**
  - `role` (required): The realm role name
  - `realm` (required): The realm path
- **Response:** Ephemeral message showing link status

### `/gnolinker sync user <realm> <user>`

Sync roles for another user (Admin only).

- **Parameters:**
  - `realm` (required): The realm path
  - `user` (required): The user to sync (user selector)
- **Response:** Ephemeral message showing sync results
- **Side Effects:** Updates target user's Discord roles

## Features

### Rich Embeds

- All responses use Discord embeds for better formatting
- Color coding: Green (success), Red (error), Yellow (warning)
- Clear status indicators with emojis

### Interactive Components

- **Buttons:** Confirmation dialogs for admin actions
- **Links:** Direct links to claim on gno.land
- **User Selectors:** Easy user selection for admin commands

### Privacy & Security

- **Ephemeral Responses:** Sensitive data shown only to command user
- **Permission Checks:** Admin commands restricted by Discord permissions
- **Role Verification:** Automatic role updates based on realm membership

### Direct Message Handling

- DMs to the bot receive a friendly redirect message
- Users are directed to use `/gnolinker` commands in server channels
- All functionality requires guild context for proper role management

## Implementation Details

### File Structure

- `interactions.go`: Slash command handlers and interaction logic
- `bot.go`: Bot initialization and event routing
- `platform.go`: Discord platform adapter implementation

### Key Components

1. **InteractionHandlers**: Manages all slash command interactions
2. **Command Registration**: Automatic guild-specific registration on bot startup
3. **Response Types**: Immediate, deferred, and follow-up responses
4. **Component Handling**: Button and select menu interactions
5. **DM Handler**: Simple redirect message for direct messages

### Command Registration Strategy

- **Single Command:** `/gnolinker` registered per guild
- **Subcommand Groups:** `link`, `verify`, `sync` with organized subcommands
- **Guild-only:** All commands require guild context (no DM support)
- Commands registered automatically on bot startup

### Namespace Benefits

- **No Collisions:** Single `/gnolinker` command avoids conflicts with other bots
- **Organization:** Logical grouping of related functionality
- **Discoverability:** Clear hierarchy makes features easy to find
- **Consistency:** All bot functionality under one command

### Configuration

Required config values:

- `GuildID`: Discord server ID for guild command registration
- `AdminRoleID`: Role ID for admin permissions
- `VerifiedAddressRoleID`: Role given to verified users

Optional config values:

- `CleanupOldCommands`: Remove all existing slash commands on startup (default: false)

### Design Decisions

- **Guild-only commands:** All functionality requires server context for role management
- **Single command structure:** Eliminates namespace conflicts with other bots
- **Ephemeral responses:** All responses are private to maintain channel cleanliness
- **No text commands:** Clean modern interface with slash commands only
- **DM redirect:** Friendly guidance to use commands in proper context

## Command Cleanup

### Removing Old Slash Commands

If you have old registered commands that need to be removed, use the cleanup flag:

```bash
# Remove all existing slash commands and register fresh ones
gnolinker discord --cleanup-commands --token=... --guild=... --admin-role=... --verified-role=...
```

### When to Use Cleanup

Use `--cleanup-commands` when:

- **Upgrading from text commands:** Remove old `/link`, `/verify`, `/sync`, `/admin` commands
- **Command structure changes:** Clean slate for new command organization
- **Development/Testing:** Reset commands during development cycles
- **Multiple bots:** Clear commands from different bot versions

### What Gets Removed

The cleanup process removes:

- ✅ **All guild-specific commands** in the configured guild
- ✅ **All global commands** registered by the bot
- ✅ **Both old individual commands** (`/link`, `/verify`, etc.)
- ✅ **Any orphaned commands** from previous versions

### Safety Notes

- **One-time use:** Only run cleanup when needed, not on every startup
- **Guild-specific:** Only affects the configured guild, not other servers
- **Logging:** All deletions are logged for verification
- **No data loss:** Only removes command registrations, not user data