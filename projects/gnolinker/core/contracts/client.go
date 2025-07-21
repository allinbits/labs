package contracts

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
)

// GnoClient wraps a gnoclient for contract interactions
type GnoClient struct {
	client gnoclient.Client
	config ClientConfig
	logger core.Logger
}

// ClientConfig holds the contract configuration
type ClientConfig struct {
	RPCURL       string
	UserContract string
	RoleContract string
}

// NewGnoClient creates a new Gno client
func NewGnoClient(config ClientConfig) (*GnoClient, error) {
	rpcClient, err := rpcclient.NewHTTPClient(config.RPCURL)
	if err != nil {
		return nil, fmt.Errorf("failed to create RPC client: %w", err)
	}

	client := gnoclient.Client{
		RPCClient: rpcClient,
	}

	// Create a logger for the client
	logger := core.NewSlogLogger(core.ParseLogLevel("info"))

	return &GnoClient{
		client: client,
		config: config,
		logger: logger,
	}, nil
}

// GetLinkedAddress returns the Gno address linked to a platform user ID
func (c *GnoClient) GetLinkedAddress(platformID string) (string, error) {
	query := fmt.Sprintf(`GetLinkedAddress("%v")`, platformID)
	contractPath := "gno.land/" + c.config.UserContract

	c.logger.Debug("Querying GetLinkedAddress", "platform_id", platformID, "contract", contractPath, "query", query)

	result, _, err := c.client.QEval(contractPath, query)
	if err != nil {
		c.logger.Error("GetLinkedAddress query failed", "error", err, "platform_id", platformID, "contract", contractPath)
		return "", fmt.Errorf("failed to get linked address: %w", err)
	}

	c.logger.Info("GetLinkedAddress result", "platform_id", platformID, "raw_result", result)
	address := parseGnoAddress(result)
	c.logger.Info("GetLinkedAddress parsed", "platform_id", platformID, "address", address)

	return address, nil
}

// GetLinkedRole returns the role mapping for a specific realm role
func (c *GnoClient) GetLinkedRole(realmPath, roleName, platformGuildID string) (*core.RoleMapping, error) {
	query := fmt.Sprintf(`GetLinkedDiscordRoleJSON("%v", "%v", "%v")`, realmPath, roleName, platformGuildID)
	result, _, err := c.client.QEval("gno.land/"+c.config.RoleContract, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get linked role: %w", err)
	}
	return parseLinkedRole(result)
}

// ListLinkedRoles returns all role mappings for a realm
func (c *GnoClient) ListLinkedRoles(realmPath, platformGuildID string) ([]*core.RoleMapping, error) {
	query := fmt.Sprintf(`ListLinkedRolesJSON("%v", "%v")`, realmPath, platformGuildID)
	contractPath := "gno.land/" + c.config.RoleContract

	c.logger.Debug("Querying ListLinkedRoles", "realm_path", realmPath, "guild_id", platformGuildID, "contract", contractPath, "query", query)

	result, _, err := c.client.QEval(contractPath, query)
	if err != nil {
		c.logger.Error("ListLinkedRoles query failed", "error", err, "realm_path", realmPath, "guild_id", platformGuildID, "contract", contractPath)
		return nil, fmt.Errorf("failed to list linked roles: %w", err)
	}

	c.logger.Info("ListLinkedRoles result", "realm_path", realmPath, "guild_id", platformGuildID, "raw_result", result)

	roles, err := parseLinkedRoles(result)
	if err != nil {
		c.logger.Error("Failed to parse linked roles", "error", err, "raw_result", result)
		return nil, err
	}

	c.logger.Info("ListLinkedRoles parsed", "realm_path", realmPath, "guild_id", platformGuildID, "role_count", len(roles))

	return roles, nil
}

// HasRole checks if an address has a specific role in the realm
func (c *GnoClient) HasRole(realmPath, roleName, address string) (bool, error) {
	query := fmt.Sprintf(`HasRole("%v", "%v")`, roleName, address)

	c.logger.Debug("Querying HasRole", "realm_path", realmPath, "role_name", roleName, "address", address, "query", query)

	result, _, err := c.client.QEval(realmPath, query)
	if err != nil {
		c.logger.Error("HasRole query failed", "error", err, "realm_path", realmPath, "role_name", roleName, "address", address)
		return false, fmt.Errorf("failed to check role membership: %w", err)
	}

	c.logger.Info("HasRole result", "realm_path", realmPath, "role_name", roleName, "address", address, "raw_result", result)

	isMember := result == "(true bool)"
	c.logger.Info("HasRole parsed", "realm_path", realmPath, "role_name", roleName, "address", address, "is_member", isMember)

	return isMember, nil
}

// Parsing functions (same as before)

func parseGnoAddress(s string) string {
	s, found := strings.CutPrefix(s, `("`)
	if !found {
		return ""
	}
	s, found = strings.CutSuffix(s, `" .uverse.address)`)
	if !found {
		return ""
	}
	return s
}

// LinkedRoleJSON is the JSON structure returned by the contract
type LinkedRoleJSON struct {
	RealmPath      string
	RealmRoleName  string
	DiscordRoleID  string
	DiscordGuildID string
}

func parseLinkedRole(s string) (*core.RoleMapping, error) {
	s, found := strings.CutPrefix(s, `("`)
	if !found {
		return nil, errors.New("parsing error: prefix not found")
	}
	s, found = strings.CutSuffix(s, `" string)`)
	if !found {
		return nil, errors.New("parsing error: suffix not found")
	}
	s = strings.ReplaceAll(s, `\`, "")

	var lr LinkedRoleJSON
	if err := json.Unmarshal([]byte(s), &lr); err != nil {
		return nil, err
	}

	return &core.RoleMapping{
		RealmPath:     lr.RealmPath,
		RealmRoleName: lr.RealmRoleName,
		PlatformRole: core.PlatformRole{
			ID:   lr.DiscordRoleID,
			Name: "", // Will be filled by platform layer
		},
	}, nil
}

func parseLinkedRoles(s string) ([]*core.RoleMapping, error) {
	s, found := strings.CutPrefix(s, `("`)
	if !found {
		return nil, errors.New("parsing error: prefix not found")
	}
	s, found = strings.CutSuffix(s, `" string)`)
	if !found {
		return nil, errors.New("parsing error: suffix not found")
	}
	s = strings.ReplaceAll(s, `\`, "")

	var roles []LinkedRoleJSON
	if err := json.Unmarshal([]byte(s), &roles); err != nil {
		return nil, err
	}

	mappings := make([]*core.RoleMapping, len(roles))
	for i, lr := range roles {
		mappings[i] = &core.RoleMapping{
			RealmPath:     lr.RealmPath,
			RealmRoleName: lr.RealmRoleName,
			PlatformRole: core.PlatformRole{
				ID:   lr.DiscordRoleID,
				Name: "", // Will be filled by platform layer
			},
		}
	}

	return mappings, nil
}
