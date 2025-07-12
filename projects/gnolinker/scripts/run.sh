#!/bin/bash

# Usage: ./scripts/run.sh [env]
# Examples:
#   ./scripts/run.sh         # uses .env
#   ./scripts/run.sh dev     # uses .dev.env  
#   ./scripts/run.sh stg     # uses .stg.env
#   ./scripts/run.sh prod    # uses .prod.env

ENV=${1:-""}
ENV_FILE=".env"

if [ -n "$ENV" ]; then
    ENV_FILE=".$ENV.env"
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found"
    echo "Available environments:"
    ls -1 .*.env 2>/dev/null | sed 's/^\./  /' | sed 's/\.env$//'
    exit 1
fi

echo "Loading environment from: $ENV_FILE"
source "$ENV_FILE"

# Build and run
go build -o gnolinker ./cmd/
./gnolinker discord