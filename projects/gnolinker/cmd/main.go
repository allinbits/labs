package main

import (
	"fmt"
	"os"

	"github.com/allinbits/labs/projects/gnolinker/cmd/discord"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	subcommand := os.Args[1]
	
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
	case "help", "--help", "-h":
		printUsage()
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

Available platforms:
  discord      Run Discord bot
  telegram     Run Telegram bot (not implemented)
  slack        Run Slack bot (not implemented)

Examples:
  gnolinker discord --token=... --guild=... --admin-role=...
  gnolinker discord --help

Environment variables:
  All environment variables use the GNOLINKER__ prefix:
  GNOLINKER__DISCORD_TOKEN, GNOLINKER__DISCORD_GUILD_ID, etc.
  GNOLINKER__GNOLAND_RPC_ENDPOINT, GNOLINKER__BASE_URL, etc.

For platform-specific help:
  gnolinker discord --help
`)
}