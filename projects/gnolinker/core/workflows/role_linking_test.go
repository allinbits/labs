package workflows

import (
	"strings"
	"testing"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
	"golang.org/x/crypto/nacl/sign"
)

func TestRoleLinkingWorkflow_GetClaimURL(t *testing.T) {
	// Setup
	_, privKey, _ := sign.GenerateKey(nil)
	client := &contracts.GnoClient{}
	config := WorkflowConfig{
		BaseURL:      "https://example.com",
		RoleContract: "r/linker/role/v0",
		SigningKey:   privKey,
	}

	workflow := NewRoleLinkingWorkflow(client, config)

	t.Run("link claim URL", func(t *testing.T) {
		claim := &core.Claim{
			Type:      core.ClaimTypeRoleLink,
			Data:      "1000,user123,guild456,role789,g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5,admin,gno.land/r/demo/app",
			Signature: "test-signature",
			CreatedAt: time.Now(),
		}

		url := workflow.GetClaimURL(claim)

		// Should be a link URL with query parameters
		if !strings.HasPrefix(url, "https://example.com/r/linker/role/v0:link?") {
			t.Errorf("Expected URL to start with link endpoint, got %q", url)
		}

		// Should contain all required parameters
		requiredParams := []string{
			"blockHeight=1000",
			"discordAccountID=user123",
			"discordGuildID=guild456",
			"discordRoleID=role789",
			"address=g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5",
			"roleName=admin",
			"realmPath=gno.land%2Fr%2Fdemo%2Fapp", // URL encoded
			"signature=test-signature",
		}

		for _, param := range requiredParams {
			if !strings.Contains(url, param) {
				t.Errorf("URL should contain parameter %q, got %q", param, url)
			}
		}
	})

	t.Run("unlink claim URL", func(t *testing.T) {
		claim := &core.Claim{
			Type:      core.ClaimTypeRoleUnlink,
			Data:      "1000,user123,guild456,gno.land/r/demo/app,admin",
			Signature: "test-signature",
			CreatedAt: time.Now(),
		}

		url := workflow.GetClaimURL(claim)

		// Should be an unlink URL with query parameters
		if !strings.HasPrefix(url, "https://example.com/r/linker/role/v0:unlink?") {
			t.Errorf("Expected URL to start with unlink endpoint, got %q", url)
		}

		// Should contain all required parameters
		requiredParams := []string{
			"blockHeight=1000",
			"discordAccountID=user123",
			"discordGuildID=guild456",
			"realmPath=gno.land%2Fr%2Fdemo%2Fapp", // URL encoded
			"roleName=admin",
			"signature=test-signature",
		}

		for _, param := range requiredParams {
			if !strings.Contains(url, param) {
				t.Errorf("URL should contain parameter %q, got %q", param, url)
			}
		}
	})
}
