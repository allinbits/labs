# Gnolinker - Multi-Platform Discord Bot

A modular Discord bot that links chat identities to Gno blockchain addresses and manages role-based permissions.

## Architecture

The refactored gnolinker is built with a modular, workflow-centric architecture:

### CLI Structure

The CLI uses a subcommand pattern to support multiple platforms:

```bash
gnolinker <platform> [options]
```

Available platforms:
- `discord` - Discord bot (implemented)
- `telegram` - Telegram bot (planned)
- `slack` - Slack bot (planned)

### Code Structure

```
gnolinker/
├── core/                    # Platform-agnostic business logic
│   ├── workflows/           # Core workflows (user linking, role linking, sync)
│   ├── contracts/           # Gno contract client
│   └── models.go            # Domain models
├── platforms/               # Platform-specific implementations
│   ├── discord/             # Discord bot implementation
│   └── platform.go         # Platform interface
├── cmd/                     # Entry points
│   ├── discord/             # Discord bot CLI
│   └── main.go              # Main CLI entry point
└── README.md
```

## Features

### Core Workflows

1. **User Linking**: Links chat user IDs to Gno addresses via cryptographic claims
2. **Role Linking**: Maps Gno realm roles to chat platform roles (organizer-only)
3. **Sync**: Reconciles role membership between Gno realms and chat platforms

### Gno Integration

- Connects to any Gno network via configurable RPC URL
- Configurable contract paths for user and role linking
- QEval-based contract interactions for queries

### Platform Abstraction

- Clean separation between business logic and platform-specific code
- Discord is the first implementation, designed to support additional platforms
- Workflow-centric command handling

## Quick Start

### Prerequisites

- Go 1.24+
- Discord bot token
- Gno network access

### Installation

```bash
cd projects/gnolinker
go mod tidy
go build -o gnolinker ./cmd/
```

### Configuration

#### Environment Files

The bot supports multiple environment files for different deployment scenarios:

- `.env` - Local development (default, gitignored)
- `.dev.env` - Development environment (gitignored)  
- `.stg.env` - Staging environment (committed)
- `.prod.env` - Production environment (gitignored)

Copy `.env.example` to your desired environment file and configure your values.

#### Makefile Usage

```bash
make dev                    # Uses .env (default)
make dev dotenv=.dev.env    # Uses .dev.env
make dev dotenv=.stg.env    # Uses .stg.env
make dev dotenv=.prod.env   # Uses .prod.env

# Other targets
make build                  # Build binary
make clean                  # Clean build artifacts
make help                   # Show available options
```

#### Manual Environment Variables

Set environment variables directly or use command-line flags:

```bash
export GNOLINKER__DISCORD_TOKEN="your-bot-token"
export GNOLINKER__DISCORD_GUILD_ID="your-server-id"
export GNOLINKER__DISCORD_ADMIN_ROLE_ID="admin-role-id"
export GNOLINKER__DISCORD_VERIFIED_ROLE_ID="verified-role-id"
export GNOLINKER__SIGNING_KEY="hex-encoded-signing-key"
export GNOLINKER__GNOLAND_RPC_ENDPOINT="https://rpc.gno.land:443"
export GNOLINKER__BASE_URL="https://gno.land"
export GNOLINKER__USER_CONTRACT="gno.land/r/linker000/discord/user/v0"
export GNOLINKER__ROLE_CONTRACT="gno.land/r/linker000/discord/role/v0"
```

### Running

```bash
# Using environment variables
./gnolinker discord

# Or using command-line flags
./gnolinker discord \
  -token="your-bot-token" \
  -guild="your-server-id" \
  -admin-role="admin-role-id" \
  -verified-role="verified-role-id" \
  -signing-key="hex-key" \
  -rpc-url="https://rpc.gno.land:443" \
  -base-url="https://gno.land"

# See available platforms
./gnolinker help

# Platform-specific help
./gnolinker discord --help
```

## Usage

### Commands

All commands are executed via DM with the bot:

#### User Commands
- `!link address {address}` - Generate claim to link Discord ID to Gno address
- `!verify address` - Verify and update address linking status
- `!sync roles {realmPath}` - Sync all roles for a realm

#### Admin Commands
- `!link role {roleName} {realmPath}` - Link realm role to Discord role
- `!verify role {roleName} {realmPath}` - Verify role linking and update membership
- `!sync roles {realmPath} {userID}` - Sync roles for another user

#### Help
- `!help` - Show available commands

### Example Workflow

1. **User links their address:**
   ```
   !link address g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
   ```

2. **Admin links a realm role:**
   ```
   !link role member gno.land/r/demo/events
   ```

3. **User verifies and syncs their roles:**
   ```
   !verify address
   !sync roles gno.land/r/demo/events
   ```

## Development

### Testing

```bash
go test ./...
```

### Adding New Platforms

1. Create platform adapter in `platforms/newplatform/`
2. Implement the `Platform` interface
3. Create platform-specific bot implementation
4. Add entry point in `cmd/newplatform/`

### Adding New Networks

Update `config/networks.go` with new network configuration:

```go
{
    Name:    "newnetwork",
    RPCURL:  "https://rpc.newnetwork.example.com",
    ChainID: "newnetwork",
    Contracts: core.NetworkContracts{
        UserLinker: "gno.land/r/linker/user",
        RoleLinker: "gno.land/r/linker/role",
    },
}
```

## Design Decisions

### Single-Server Model

Each bot instance manages one chat server to:
- Maintain clear trust boundaries
- Simplify permission models
- Encourage community ownership of bot instances
- Avoid cross-server role conflicts

### Workflow-Centric Architecture

Organized around business workflows rather than platform features:
- User linking workflow
- Role linking workflow  
- Sync workflow

This makes it easier to:
- Test business logic independently
- Add new platforms
- Maintain consistency across platforms

### Multi-Network Support

Allows single bot to work with multiple Gno networks:
- Development against testnets
- Production on mainnet
- Local development environments
- Custom network deployments

## Migration from Legacy

The legacy `gnolinker.go` remains functional during transition. The new architecture provides:

- Better separation of concerns
- Improved testability
- Platform extensibility
- Multi-network support
- Cleaner command handling

## Contributing

1. Follow the existing architecture patterns
2. Add tests for new workflows
3. Document any new configuration options
4. Consider platform-agnostic design for new features