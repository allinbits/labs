
# This makefile assumes there is a .env file for `make run` to work
# file: .env
# GNOID_DISCORD_TOKEN=FOO
# GNOID_KEY=BAR

# Default environment file
dotenv ?= .env

# Load environment file if it exists
ifneq (,$(wildcard ./$(dotenv)))
	include ./$(dotenv)
	export
endif

.PHONY: help dev build clean

# Show available targets
help:
	@echo "Available targets:"
	@echo "  dev                   Start development server with hot reload"
	@echo "  build                 Build the gnolinker binary"
	@echo "  clean                 Remove build artifacts"
	@echo "  help                  Show this help"
	@echo ""
	@echo "Environment files:"
	@echo "  dev                   Uses .env (default)"
	@echo "  dev dotenv=.dev.env   Uses .dev.env"
	@echo "  dev dotenv=.stg.env   Uses .stg.env"
	@echo "  dev dotenv=.prod.env  Uses .prod.env"
	@echo ""
	@echo "Examples:"
	@echo "  make dev              # Development with .env"
	@echo "  make dev dotenv=.stg.env  # Development with staging config"

# Development server with hot reload
dev:
	@echo "Starting development server with $(dotenv)..."
	@find . -name "*.go" | entr -r go run cmd/main.go discord

# Build the binary
build:
	@go build -o gnolinker ./cmd/

# Clean build artifacts
clean:
	@rm -f gnolinker