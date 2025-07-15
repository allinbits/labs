package main

import (
	"fmt"
	"os"

	"github.com/allinbits/labs/projects/gnolinker/cmd/discord"
)

func main() {
	// Handle the case where no arguments are provided
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	// Extract subcommand
	subcommand := os.Args[1]
	
	// Handle help and version at the top level
	switch subcommand {
	case "help", "--help", "-h":
		printUsage()
		return
	case "version", "--version", "-v":
		fmt.Println("gnolinker version dev")
		return
	}
	
	// Route to platform-specific subcommands
	// Remove the subcommand from args so subcommands can parse their own flags
	os.Args = append(os.Args[:1], os.Args[2:]...)
	
	switch subcommand {
	case "discord":
		discord.Run()
	case "telegram":
		fmt.Println("Telegram support is not yet implemented")
		os.Exit(1)
	case "slack":
		fmt.Println("Slack support is not yet implemented") 
		os.Exit(1)
	default:
		fmt.Printf("Unknown subcommand: %s\n\n", subcommand)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Printf(`gnolinker - Multi-platform bot for linking chat identities to Gno addresses

Usage:
  gnolinker <platform> [options]
  gnolinker <command>

Available platforms:
  discord      Run Discord bot
  telegram     Run Telegram bot (not implemented)
  slack        Run Slack bot (not implemented)

Available commands:
  help         Show this help message
  version      Show version information

Examples:
  gnolinker discord --token=...
  gnolinker discord --log-level=debug --token=... --admin-role=... --verified-role=...
  gnolinker discord --help
  gnolinker version

Environment variables:
  Bot configuration (GNOLINKER__ prefix):
    GNOLINKER__DISCORD_TOKEN, GNOLINKER__SIGNING_KEY
    GNOLINKER__GNOLAND_RPC_ENDPOINT, GNOLINKER__BASE_URL
    GNOLINKER__LOG_LEVEL (debug, info, warn, error)
  
  Storage configuration (GNOLINKER__ prefix):
    GNOLINKER__STORAGE_TYPE (memory, s3)
    GNOLINKER__STORAGE_BUCKET, GNOLINKER__STORAGE_PREFIX
  
  Distributed locking (GNOLINKER__ prefix):
    GNOLINKER__LOCK_TYPE (s3, memory, none)
    GNOLINKER__LOCK_BUCKET, GNOLINKER__LOCK_PREFIX, GNOLINKER__LOCK_DEFAULT_TTL
  
  AWS SDK standard variables (for S3 storage/locking):
    AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    AWS_ENDPOINT_URL_S3, AWS_ENDPOINT_URL (for S3-compatible services)
  
Note: Admin and verified roles are now auto-detected/created per guild.
Use --admin-role and --verified-role flags only to override defaults.

For platform-specific help:
  gnolinker discord --help
`)
}