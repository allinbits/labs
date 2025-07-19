package discord

import (
	"context"
	"encoding/hex"
	"flag"
	"os"
	"strconv"
	"strings"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/config"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
	"github.com/allinbits/labs/projects/gnolinker/core/workflows"
	"github.com/allinbits/labs/projects/gnolinker/platforms/discord"
)

func Run() {
	// Command line flags
	var (
		tokenFlag              = flag.String("token", "", "Discord bot token")
		signingKeyFlag         = flag.String("signing-key", "", "Hex encoded signing key")
		rpcURLFlag             = flag.String("rpc-url", "https://rpc.gno.land:443", "Gno RPC URL")
		baseURLFlag            = flag.String("base-url", "https://gno.land", "Base URL for claim links")
		userContractFlag       = flag.String("user-contract", "r/linker000/discord/user/v0", "User contract path")
		roleContractFlag       = flag.String("role-contract", "r/linker000/discord/role/v0", "Role contract path")
		logLevelFlag           = flag.String("log-level", "info", "Log level (debug, info, warn, error)")
		cleanupFlag            = flag.Bool("cleanup-commands", false, "Remove all existing slash commands on startup")
		graphqlEndpointFlag    = flag.String("graphql-endpoint", "", "GraphQL HTTP endpoint for event monitoring")
		enableEventMonitorFlag = flag.Bool("enable-event-monitoring", false, "Enable real-time event monitoring")
	)
	flag.Parse()
	
	// Load log level from environment or flag
	logLevel := getEnvOrFlag("GNOLINKER__LOG_LEVEL", *logLevelFlag)
	
	// Initialize logger with configurable level
	logger := core.NewLoggerFromLevel(logLevel)
	logger.Info("Starting gnolinker Discord bot", "log_level", logLevel)

	// Initialize configuration manager (includes storage and lock manager)
	ctx := context.Background()
	configManager, err := config.InitializeConfigManager(ctx, logger)
	if err != nil {
		logger.Error("Failed to initialize configuration manager", "error", err)
		os.Exit(1)
	}

	// Load from environment if flags not provided
	token := getEnvOrFlag("GNOLINKER__DISCORD_TOKEN", *tokenFlag)
	signingKeyStr := getEnvOrFlag("GNOLINKER__SIGNING_KEY", *signingKeyFlag)
	rpcURL := getEnvOrFlag("GNOLINKER__GNOLAND_RPC_ENDPOINT", *rpcURLFlag)
	baseURL := getEnvOrFlag("GNOLINKER__BASE_URL", *baseURLFlag)
	userContract := getEnvOrFlag("GNOLINKER__USER_CONTRACT", *userContractFlag)
	roleContract := getEnvOrFlag("GNOLINKER__ROLE_CONTRACT", *roleContractFlag)
	graphqlEndpoint := getEnvOrFlag("GNOLINKER__GRAPHQL_ENDPOINT", *graphqlEndpointFlag)
	enableEventMonitoring := getEnvOrBool("GNOLINKER__ENABLE_EVENT_MONITORING", *enableEventMonitorFlag)

	// Validate required parameters
	if token == "" {
		logger.Error("Discord token is required (use -token flag or GNOLINKER__DISCORD_TOKEN env var)")
		os.Exit(1)
	}
	if signingKeyStr == "" {
		logger.Error("Signing key is required (use -signing-key flag or GNOLINKER__SIGNING_KEY env var)")
		os.Exit(1)
	}

	// Roles are now managed per-guild by ConfigManager
	storageConfig := configManager.GetStorageConfig()
	logger.Info("Roles will be managed per-guild", "auto_create_roles", storageConfig.AutoCreateRoles, "default_verified_role_name", storageConfig.DefaultVerifiedRoleName)
	
	// Log GraphQL event monitoring configuration
	if enableEventMonitoring && graphqlEndpoint != "" {
		logger.Info("GraphQL event monitoring enabled with polling", "endpoint", graphqlEndpoint)
	} else if enableEventMonitoring && graphqlEndpoint == "" {
		logger.Warn("Event monitoring enabled but no GraphQL endpoint specified")
	} else {
		logger.Info("GraphQL event monitoring disabled")
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

	// Create Discord config - roles are now managed by ConfigManager
	discordConfig := discord.Config{
		Token:                 token,
		CleanupOldCommands:    *cleanupFlag,
		GraphQLEndpoint:       graphqlEndpoint,
		EnableEventMonitoring: enableEventMonitoring,
		// Remove hard-coded roles - these will be managed dynamically per guild
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

	// Create and start bot with config manager
	bot, err := discord.NewBot(discordConfig, userFlow, roleFlow, syncFlow, configManager, logger)
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

func getEnvOrBool(envVar string, flagValue bool) bool {
	if envValue := os.Getenv(envVar); envValue != "" {
		// Parse boolean from environment variable
		switch strings.ToLower(envValue) {
		case "true", "1", "yes", "on":
			return true
		case "false", "0", "no", "off":
			return false
		default:
			// If invalid value, try to parse as boolean
			if parsed, err := strconv.ParseBool(envValue); err == nil {
				return parsed
			}
		}
	}
	return flagValue
}
