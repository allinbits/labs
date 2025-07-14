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
  gnolinker discord --token=... --admin-role=... --verified-role=...
  gnolinker discord --log-level=debug --token=...
  gnolinker discord --help
  gnolinker version

Environment variables:
  All environment variables use the GNOLINKER__ prefix:
  GNOLINKER__DISCORD_TOKEN, GNOLINKER__DISCORD_ADMIN_ROLE_ID, etc.
  GNOLINKER__GNOLAND_RPC_ENDPOINT, GNOLINKER__BASE_URL, etc.
  GNOLINKER__LOG_LEVEL (debug, info, warn, error)

For platform-specific help:
  gnolinker discord --help
`)
}