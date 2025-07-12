package workflows

import (
	"encoding/base64"
	"fmt"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
	"golang.org/x/crypto/nacl/sign"
)

// UserLinkingWorkflowImpl implements the user linking workflow
type UserLinkingWorkflowImpl struct {
	gnoClient *contracts.GnoClient
	config    WorkflowConfig
}

// NewUserLinkingWorkflow creates a new user linking workflow
func NewUserLinkingWorkflow(client *contracts.GnoClient, config WorkflowConfig) UserLinkingWorkflow {
	return &UserLinkingWorkflowImpl{
		gnoClient: client,
		config:    config,
	}
}

// GenerateClaim creates a signed claim for linking a platform user to a Gno address
func (w *UserLinkingWorkflowImpl) GenerateClaim(platformID, gnoAddress string) (*core.Claim, error) {
	timestamp := time.Now()
	message := fmt.Sprintf("%v,%v,%v", timestamp.Unix(), platformID, gnoAddress)
	signedMessage := sign.Sign(nil, []byte(message), w.config.SigningKey)
	signature := base64.RawURLEncoding.EncodeToString(signedMessage)
	
	return &core.Claim{
		Type:      core.ClaimTypeUserLink,
		Data:      message,
		Signature: signature,
		CreatedAt: timestamp,
	}, nil
}

// GetLinkedAddress retrieves the Gno address linked to a platform user
func (w *UserLinkingWorkflowImpl) GetLinkedAddress(platformID string) (string, error) {
	return w.gnoClient.GetLinkedAddress(platformID)
}

// GetClaimURL returns the URL where users can submit their claim
func (w *UserLinkingWorkflowImpl) GetClaimURL(claim *core.Claim) string {
	// Format: https://baseurl/r/linker000/discord/user/v0:claim/signature
	return fmt.Sprintf("%s/%s:claim/%s", w.config.BaseURL, w.config.UserContract, claim.Signature)
}