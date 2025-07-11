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

	return &GnoClient{
		client: client,
		config: config,
	}, nil
}

// GetLinkedAddress returns the Gno address linked to a platform user ID
func (c *GnoClient) GetLinkedAddress(platformID string) (string, error) {
	query := fmt.Sprintf(`GetLinkedAddress("%v")`, platformID)
	result, _, err := c.client.QEval("gno.land/"+c.config.UserContract, query)
	if err != nil {
		return "", fmt.Errorf("failed to get linked address: %w", err)
	}
	fmt.Println("GetLinkedAddress result:", result)
	return parseGnoAddress(result), nil
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
	result, _, err := c.client.QEval("gno.land/"+c.config.RoleContract, query)
	if err != nil {
		return nil, fmt.Errorf("failed to list linked roles: %w", err)
	}
	return parseLinkedRoles(result)
}

// HasRole checks if an address has a specific role in the realm
func (c *GnoClient) HasRole(realmPath, roleName, address string) (bool, error) {
	query := fmt.Sprintf(`HasRole("%v", "%v")`, roleName, address)
	result, _, err := c.client.QEval(realmPath, query)
	if err != nil {
		return false, fmt.Errorf("failed to check role membership: %w", err)
	}
	fmt.Println("HasRole result:", result)
	return result == "(true bool)", nil
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
