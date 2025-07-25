# Gnolinker - Chat Bot

A chat bot that links chat identities to Gno blockchain addresses and manages role-based permissions with distributed locking and persistent storage. Currently implements Discord, with support for additional platforms planned.

## Architecture

The gnolinker is built with a modular, workflow-centric architecture:

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

```shell
gnolinker/
├── core/                    # Platform-agnostic business logic
│   ├── workflows/           # Core workflows (user linking, role linking, sync)
│   ├── contracts/           # Gno contract client
│   ├── storage/             # Persistent storage implementations (memory, S3)
│   ├── lock/                # Distributed locking (memory, S3, no-op)
│   ├── config/              # Configuration management with auto-role detection
│   └── models.go            # Domain models
├── platforms/               # Platform-specific implementations
│   ├── discord/             # Discord bot implementation with role management
│   └── platform.go         # Platform interface
├── cmd/                     # Entry points
│   ├── discord/             # Discord bot CLI
│   └── main.go              # Main CLI entry point
└── README.md
```

## Features

### Core Workflows

1. **User Linking**: Links chat user IDs to Gno addresses via cryptographic claims
2. **Role Linking**: Maps Gno realm roles to chat platform roles (admin-only)
3. **Sync**: Reconciles role membership between Gno realms and chat platforms

### Gno Integration

- Connects to any Gno network via configurable RPC URL
- Configurable contract paths for user and role linking
- QEval-based contract interactions for queries

### Platform Abstraction

- Clean separation between business logic and platform-specific code
- Discord is the first platform implementation, designed to support additional chat platforms
- Workflow-centric command handling

### Automatic Role Management

- **Multi-Server Support**: Roles are managed per-guild automatically (Discord implementation)
- **Admin Role Auto-Detection**: Bot automatically detects admin roles based on platform permissions
- **Verified Role Auto-Creation**: Creates "Gno-Verified" role automatically when needed
- **No Manual Configuration**: No need to specify role IDs in environment variables
- **Distributed Role Creation**: Safe concurrent role creation across multiple bot instances

### Scalable Architecture

- **Distributed Locking**: Prevents race conditions across multiple bot instances
- **Persistent Storage**: S3-compatible storage for configurations and state
- **Horizontal Scaling**: Multiple bot instances can run safely with shared storage
- **Memory & S3 Backends**: Configurable storage backends for different deployment scenarios

## Quick Start

### Prerequisites

- Go 1.24+
- Discord bot token (for Discord platform)
- Gno network access

### Installation

```bash
cd projects/gnolinker
go mod tidy
go build -o gnolinker ./cmd/
```

### Configuration

Copy `.env.example` to `.env` and configure your values:

```bash
GNOLINKER__SIGNING_KEY={SIGNING_KEY} # in secrets store
GNOLINKER__GNOLAND_RPC_ENDPOINT=127.0.0.1:26657
#GNOLINKER__GNOLAND_RPC_ENDPOINT=https://aiblabs.net:8443 #if none local
GNOLINKER__DISCORD_TOKEN={DEV_TOKEN} # in secrets store
#GNOLINKER__BASE_URL=https://aiblabs.net
```

### Running

```bash
# Using environment variables
./gnolinker discord

# Or using command-line flags
./gnolinker discord \
  -token="your-bot-token" \
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

The Discord implementation uses modern slash commands under `/gnolinker`. All responses are private (ephemeral) to you in channels. See [SLASH_COMMANDS.md](SLASH_COMMANDS.md) for complete documentation.

#### User Commands

- `/gnolinker link address <address>` - Generate claim to link chat ID to Gno address
- `/gnolinker verify address` - Verify and update address linking status
- `/gnolinker sync roles <realm>` - Sync all roles for a realm
- `/gnolinker help` - Show all available commands

#### Admin Commands

- `/gnolinker link role <role> <realm>` - Link realm role to chat platform role
- `/gnolinker verify role <role> <realm>` - Verify role linking and update membership
- `/gnolinker sync user <realm> <user>` - Sync roles for another user

### Example Workflow

1. **User links their address:**

   ```
   /gnolinker link address g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
   ```

2. **Admin links a realm role:**

   ```
   /gnolinker link role member gno.land/r/demo/events
   ```

3. **User verifies and syncs their roles:**

   ```
   /gnolinker verify address
   /gnolinker sync roles gno.land/r/demo/events
   ```

## Development

### Local Development

```bash
# Start development environment with MinIO
make dev

# Stop services
make down

# Clean everything including data
make clean
```

### Testing

```bash
# Run all tests
make test

# Run security scanning
make security-scan
```

### Adding New Platforms

1. Create platform adapter in `platforms/newplatform/`
2. Implement the `Platform` interface
3. Create platform-specific bot implementation
4. Add entry point in `cmd/newplatform/`

## Design Decisions

### Distributed Architecture

The bot is designed to run in distributed environments:

- **Distributed Locking**: Uses S3 or memory-based locking to coordinate multiple instances
- **Shared Storage**: Configuration and state stored in S3-compatible storage
- **Horizontal Scaling**: Multiple instances can run safely without conflicts

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

## Contributing

1. Follow the existing architecture patterns
2. Add tests for new workflows
3. Document any new configuration options
4. Consider platform-agnostic design for new features
5. Run `make test` and `make security-scan` before submitting PRs
