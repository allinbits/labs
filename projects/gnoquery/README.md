# gnoquery

A simplified query tool for Gno contracts that uses the Gno client directly to execute QEval queries.

## Installation

### From source (recommended for development)

```bash
git clone https://github.com/allinbits/labs
cd labs/projects/gnoquery
make install
```

### Direct install (if published)

```bash
go install github.com/allinbits/labs/projects/gnoquery@latest
```

### Build locally

```bash
make build    # Build binary in current directory
make clean    # Clean build artifacts
make test     # Run tests
make help     # Show available targets
```

## Usage

```bash
gnoquery [flags] [realm_path] [function_call]
```

### Examples

Query a Discord role link:
```bash
gnoquery gno.land/r/linker000/discord/role 'GetLinkedDiscordRoleJSON("gno.land/r/linker000/mockevent/v1", "attendee", "1030326897667756132")'
```

Query mockevent roles:
```bash
gnoquery gno.land/r/linker000/mockevent/v1 'HasRole("attendee", "g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")'
```

Query with custom remote:
```bash
gnoquery -remote https://rpc.test.gno.land:443 gno.land/r/linker000/mockevent/v1 'HasRole("organizer", "g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")'
```

Query with environment variable:
```bash
export GNOQUERY_REMOTE=https://aiblabs.net:8443
gnoquery gno.land/r/linker000/mockevent/v1 'HasRole("attendee", "g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")'
```

### Flags

- `-remote`: Remote node URL (default: "https://rpc.gno.land:443")

### Environment Variables

- `GNOQUERY_REMOTE`: Sets the default remote URL (overridden by `-remote` flag)

## Features

- Direct Gno client integration (no shell wrappers)
- Simple argument parsing (no CLI framework dependencies)
- QEval functionality similar to gnolinker
- Raw output suitable for parsing or further processing