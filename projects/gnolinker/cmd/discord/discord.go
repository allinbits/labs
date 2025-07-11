package discord

import (
	"encoding/hex"
	"flag"
	"log"
	"os"

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
	)
	flag.Parse()

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
		log.Fatal("Discord token is required (use -token flag or GNOLINKER__DISCORD_TOKEN env var)")
	}
	if guildID == "" {
		log.Fatal("Discord guild ID is required (use -guild flag or GNOLINKER__DISCORD_GUILD_ID env var)")
	}
	if adminRole == "" {
		log.Fatal("Admin role ID is required (use -admin-role flag or GNOLINKER__DISCORD_ADMIN_ROLE_ID env var)")
	}
	if verifiedRole == "" {
		log.Fatal("Verified role ID is required (use -verified-role flag or GNOLINKER__DISCORD_VERIFIED_ROLE_ID env var)")
	}
	if signingKeyStr == "" {
		log.Fatal("Signing key is required (use -signing-key flag or GNOLINKER__SIGNING_KEY env var)")
	}

	// Decode signing key
	signingKeyBytes, err := hex.DecodeString(signingKeyStr)
	if err != nil {
		log.Fatalf("Failed to decode hex signing key: %v", err)
	}
	if len(signingKeyBytes) != 64 {
		log.Fatalf("Signing key must be 64 bytes, got %d", len(signingKeyBytes))
	}

	var signingKey [64]byte
	copy(signingKey[:], signingKeyBytes)

	// Create Discord config
	discordConfig := discord.Config{
		Token:                 token,
		GuildID:               guildID,
		AdminRoleID:           adminRole,
		VerifiedAddressRoleID: verifiedRole,
	}

	// Create Gno client
	clientConfig := contracts.ClientConfig{
		RPCURL:       rpcURL,
		UserContract: userContract,
		RoleContract: roleContract,
	}

	gnoClient, err := contracts.NewGnoClient(clientConfig)
	if err != nil {
		log.Fatalf("Failed to create Gno client: %v", err)
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
	bot, err := discord.NewBot(discordConfig, userFlow, roleFlow, syncFlow)
	if err != nil {
		log.Fatalf("Failed to create Discord bot: %v", err)
	}

	log.Printf("Starting gnolinker Discord bot connected to: %s", rpcURL)
	if err := bot.Start(); err != nil {
		log.Fatalf("Bot error: %v", err)
	}
}

func getEnvOrFlag(envVar, flagValue string) string {
	if envValue := os.Getenv(envVar); envValue != "" {
		return envValue
	}
	return flagValue
}
