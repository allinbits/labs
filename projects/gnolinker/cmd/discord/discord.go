package discord

import (
	"encoding/hex"
	"flag"
	"os"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms/discord"
)

func Run() {
	// Command line flags
	var (
		tokenFlag        = flag.String("token", "", "Discord bot token")
		guildIDFlag      = flag.String("guild", "", "Discord guild ID")
		adminRoleFlag    = flag.String("admin-role", "", "Admin role ID")
		verifiedRoleFlag = flag.String("verified-role", "", "Verified address role ID")
		signingKeyFlag   = flag.String("signing-key", "", "Hex encoded signing key")
		rpcURLFlag       = flag.String("rpc-url", "https://rpc.gno.land:443", "Gno RPC URL")
		baseURLFlag      = flag.String("base-url", "https://gno.land", "Base URL for claim links")
		userContractFlag = flag.String("user-contract", "r/linker000/discord/user/v0", "User contract path")
		roleContractFlag = flag.String("role-contract", "r/linker000/discord/role/v0", "Role contract path")
		logLevelFlag     = flag.String("log-level", "info", "Log level (debug, info, warn, error)")
		cleanupFlag      = flag.Bool("cleanup-commands", false, "Remove all existing slash commands on startup")
	)
	flag.Parse()
	
	// Load log level from environment or flag
	logLevel := getEnvOrFlag("GNOLINKER__LOG_LEVEL", *logLevelFlag)
	
	// Initialize logger with configurable level
	logger := core.NewLoggerFromLevel(logLevel)
	logger.Info("Starting gnolinker Discord bot", "log_level", logLevel)

	// Load from environment if flags not provided
	token := getEnvOrFlag("GNOLINKER__DISCORD_TOKEN", *tokenFlag)
	guildID := getEnvOrFlag("GNOLINKER__DISCORD_GUILD_ID", *guildIDFlag)
	adminRole := getEnvOrFlag("GNOLINKER__DISCORD_ADMIN_ROLE_ID", *adminRoleFlag)
	verifiedRole := getEnvOrFlag("GNOLINKER__DISCORD_VERIFIED_ROLE_ID", *verifiedRoleFlag)
	signingKeyStr := getEnvOrFlag("GNOLINKER__SIGNING_KEY", *signingKeyFlag)
	rpcURL := getEnvOrFlag("GNOLINKER__GNOLAND_RPC_ENDPOINT", *rpcURLFlag)
	baseURL := getEnvOrFlag("GNOLINKER__BASE_URL", *baseURLFlag)
	userContract := getEnvOrFlag("GNOLINKER__USER_CONTRACT", *userContractFlag)
	roleContract := getEnvOrFlag("GNOLINKER__ROLE_CONTRACT", *roleContractFlag)

	// Validate required parameters
	if token == "" {
		logger.Error("Discord token is required (use -token flag or GNOLINKER__DISCORD_TOKEN env var)")
		os.Exit(1)
	}
	if guildID == "" {
		logger.Error("Discord guild ID is required (use -guild flag or GNOLINKER__DISCORD_GUILD_ID env var)")
		os.Exit(1)
	}
	if adminRole == "" {
		logger.Error("Admin role ID is required (use -admin-role flag or GNOLINKER__DISCORD_ADMIN_ROLE_ID env var)")
		os.Exit(1)
	}
	if verifiedRole == "" {
		logger.Error("Verified role ID is required (use -verified-role flag or GNOLINKER__DISCORD_VERIFIED_ROLE_ID env var)")
		os.Exit(1)
	}
	if signingKeyStr == "" {
		logger.Error("Signing key is required (use -signing-key flag or GNOLINKER__SIGNING_KEY env var)")
		os.Exit(1)
	}

	// Decode signing key
	signingKeyBytes, err := hex.DecodeString(signingKeyStr)
	if err != nil {
		logger.Error("Failed to decode hex signing key", "error", err)
		os.Exit(1)
	}
	if len(signingKeyBytes) != 64 {
		logger.Error("Signing key must be 64 bytes", "actual", len(signingKeyBytes))
		os.Exit(1)
	}

	var signingKey [64]byte
	copy(signingKey[:], signingKeyBytes)

	// Create Discord config
	discordConfig := discord.Config{
		Token:                 token,
		GuildID:               guildID,
		AdminRoleID:           adminRole,
		VerifiedAddressRoleID: verifiedRole,
		CleanupOldCommands:    *cleanupFlag,
	}

	// Create Gno client
	clientConfig := contracts.ClientConfig{
		RPCURL:       rpcURL,
		UserContract: userContract,
		RoleContract: roleContract,
	}

	gnoClient, err := contracts.NewGnoClient(clientConfig)
	if err != nil {
		logger.Error("Failed to create Gno client", "error", err)
		os.Exit(1)
	}

	// Create workflow config
	workflowConfig := workflows.WorkflowConfig{
		SigningKey:   &signingKey,
		BaseURL:      baseURL,
		UserContract: userContract,
		RoleContract: roleContract,
	}

	// Create workflows
	userFlow := workflows.NewUserLinkingWorkflow(gnoClient, workflowConfig)
	roleFlow := workflows.NewRoleLinkingWorkflow(gnoClient, workflowConfig)
	syncFlow := workflows.NewSyncWorkflow(gnoClient, workflowConfig)

	// Create and start bot
	bot, err := discord.NewBot(discordConfig, userFlow, roleFlow, syncFlow, logger)
	if err != nil {
		logger.Error("Failed to create Discord bot", "error", err)
		os.Exit(1)
	}

	logger.Info("Starting gnolinker Discord bot", "rpc_url", rpcURL)
	if err := bot.Start(); err != nil {
		logger.Error("Bot error", "error", err)
		os.Exit(1)
	}
}

func getEnvOrFlag(envVar, flagValue string) string {
	if envValue := os.Getenv(envVar); envValue != "" {
		return envValue
	}
	return flagValue
}
