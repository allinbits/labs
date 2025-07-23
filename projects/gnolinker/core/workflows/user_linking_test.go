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
			Data:      "test-data",
			Signature: "test-signature",
			CreatedAt: time.Now(),
		}

		url := workflow.GetClaimURL(claim)
		expectedURL := "https://example.com/r/linker/user/v0:claim/test-signature"

		if url != expectedURL {
			t.Errorf("Expected URL %q, got %q", expectedURL, url)
		}

		// Should not have unlink parameter
		if strings.Contains(url, "?unlink=true") {
			t.Error("Link claim URL should not contain unlink parameter")
		}
	})

	t.Run("unlink claim URL", func(t *testing.T) {
		claim := &core.Claim{
			Type:      core.ClaimTypeUserUnlink,
			Data:      "test-data",
			Signature: "test-signature",
			CreatedAt: time.Now(),
		}

		url := workflow.GetClaimURL(claim)
		expectedURL := "https://example.com/r/linker/user/v0:claim/test-signature?unlink=true"

		if url != expectedURL {
			t.Errorf("Expected URL %q, got %q", expectedURL, url)
		}

		// Should have unlink parameter
		if !strings.Contains(url, "?unlink=true") {
			t.Error("Unlink claim URL should contain unlink parameter")
		}
	})
}
