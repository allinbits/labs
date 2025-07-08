# Gno CDN Proxy Server

STATUS: **Alpha** - POC

As users eventually wish to use off-chain resources, this project implements a CDN proxy server that routes requests to a specified backend server.
It also validates paths using Gno blockchain queries.

## Features

- **Reverse Proxy**: Routes requests to a specified backend server.
- **Path Validation**: Validates CDN paths using Gno blockchain queries.
- **Dynamic Routing**: Handles requests for GitHub-like paths (`/gh/{user}/{repo}@{version}/*`).

## Usage


```
// from /path/to/projects/gno_cdn
go run ./cmd
```


### Gnoframe

public static main(): Declaring Public Logic with gnoframe
With gnoframe, we’re not just serving static content —
we’re declaring ingress points into Gno.land.

Think of main() not as a runtime function,
but as a public, static entrypoint — the beginning of logic you can inspect, fork, and verify.

gnoframe is:

public: logic and content exposed for everyone

static: append-only, content-addressable, cache-resilient

main(): the default ingress — what loads first, what runs first

Each frame is defined by a gnoframe.toml manifest:
Declarative, deterministic, and built to survive the web’s chaos.