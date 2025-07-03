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
