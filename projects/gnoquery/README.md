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

## Usage

```bash
gnoquery [flags] [realm_path] [function_call]
```

### Examples

Query mockevent roles:

```bash
gnoquery gno.land/r/linker000/mockevent/v1 'HasRole("attendee" "g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")'
```

### Flags

- `-remote`: Remote node URL (default: "tcp://0.0.0.0:26657")

### Environment Variables

- `GNOQUERY_REMOTE`: Sets the default remote URL (overridden by `-remote` flag)

## Features

- Direct Gno client integration (no shell wrappers around gnokey)
- Simple argument parsing (no CLI framework dependencies)
- Raw output suitable for parsing or further processing