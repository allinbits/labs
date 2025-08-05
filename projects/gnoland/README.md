# gnoland

This is a repository meant to hold all gno.land smart contract related `p/` and `r/` files.

This has a local development environment so that you can run `make dev` and it will spin up hot-reload for `examples` as well as all the files in this directory.

`labsneet` current matches `test7.2` using `sha-9b384d4` as the tagged image

## Quick Start

```bash
# Start development environment
make dev

# Run in staging mode
make staging

# Test specific packages
make test path=gno.land/r/linker000/mockevent/v1

# Run all tests
make test-all
```

## Features

- **Containerized Development Environment**: Develop in a consistent environment with Docker
- **Hot Reloading**: Changes to Gno files are immediately available for testing
- **Multi-mode Operation**: Run in development or staging mode
- **Integrated Testing**: Run tests easily against your Gno packages
- **Automatic Proxy & URL Rewriting**: Using Caddy with replace-response for cleaner URLs
- **Production Deployment**: Ready for Fly.io deployment

## Environment Options

### Traditional Setup

If you prefer developing without Docker:

1) You need a local fork of `gnolang/gno` on your machine
2) You need $GNOROOT env configured to point to your fork of gno source code
3) You need `gnodev` installed. If not, please run `make install` from your fork of gno and install it first

### Docker Setup (Recommended)

No need to install Gno tools locally - everything runs in containers!

Requirements:
- Docker and Docker Compose
- Make

## Development Environment

Our Docker-based setup includes:

- **Gno Development Environment**: Built from specific commit hashes for reliability
- **Caddy Server**: Handles URL rewriting and proxying
- **Volume Mounting**: Local files are mounted directly into the container for hot reloading

### Command Reference

| Command | Description |
|---------|-------------|
| `make dev` | Start development environment with hot reloading |
| `make staging` | Start staging environment with Caddy proxy |
| `make test path=...` | Run tests for specific package |
| `make test-all` | Run all tests in the repository |
| `make build` | Build Docker images |
| `make down` | Stop and remove containers |

## Deployment

The project is configured for deployment to Fly.io:

```bash
# Deploy to Fly.io
fly deploy
```

The Fly.io configuration:
- Exposes port 8888 via HTTPS (443)
- Exposes RPC port 26657 via HTTPS (8443)
- Runs in staging mode by default

## Project Structure

```
gnoland/
├── Dockerfile        # Multi-stage Docker build
├── docker-compose.yml # Local development setup
├── Caddyfile        # Caddy configuration
├── Makefile         # Common commands
├── scripts/         # Helper scripts
│   └── entrypoint.sh # Container entrypoint
├── genesis/         # Genesis configuration
├── gno.land/        # Local Gno packages
└── fly.toml         # Fly.io deployment configuration
```

## Contributing

Contributions are welcome! Please feel free to submit a pull request.
