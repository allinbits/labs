package workflows

import (
	"strings"
	"testing"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
	"golang.org/x/crypto/nacl/sign"
)

func TestUserLinkingWorkflow_GetClaimURL(t *testing.T) {
	// Setup
	_, privKey, _ := sign.GenerateKey(nil)
	client := &contracts.GnoClient{}
	config := WorkflowConfig{
		BaseURL:      "https://example.com",
		UserContract: "r/linker/user/v0",
		SigningKey:   privKey,
	}

	workflow := NewUserLinkingWorkflow(client, config)

	t.Run("link claim URL", func(t *testing.T) {
		claim := &core.Claim{
			Type:      core.ClaimTypeUserLink,
			Data:      "1000,123456789012345678,g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5",
			Signature: "test-signature",
			CreatedAt: time.Now(),
		}

		url := workflow.GetClaimURL(claim)

		// Should be a link URL with query parameters
		if !strings.HasPrefix(url, "https://example.com/r/linker/user/v0:link?") {
			t.Errorf("Expected URL to start with link endpoint, got %q", url)
		}

		// Should contain all required parameters
		requiredParams := []string{
			"blockHeight=1000",
			"discordID=123456789012345678",
			"address=g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5",
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
			Type:      core.ClaimTypeUserUnlink,
			Data:      "1000,123456789012345678",
			Signature: "test-signature",
			CreatedAt: time.Now(),
		}

		url := workflow.GetClaimURL(claim)

		// Should be an unlink URL with query parameters
		if !strings.HasPrefix(url, "https://example.com/r/linker/user/v0:unlink?") {
			t.Errorf("Expected URL to start with unlink endpoint, got %q", url)
		}

		// Should contain all required parameters
		requiredParams := []string{
			"blockHeight=1000",
			"discordID=123456789012345678",
			"signature=test-signature",
		}

		for _, param := range requiredParams {
			if !strings.Contains(url, param) {
				t.Errorf("URL should contain parameter %q, got %q", param, url)
			}
		}
	})
}
