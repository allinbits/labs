package workflows

import (
	"encoding/base64"
	"fmt"
	"strings"
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
	// Get current block height
	blockHeight, err := w.gnoClient.GetCurrentBlockHeight()
	if err != nil {
		return nil, fmt.Errorf("failed to get current block height: %w", err)
	}

	// Create message with block height instead of timestamp
	message := fmt.Sprintf("%d,%s,%s", blockHeight, platformID, gnoAddress)
	
	// Sign only the message (not the full signed message)
	signature := sign.Sign(nil, []byte(message), w.config.SigningKey)[:64] // Only the signature part
	signatureEncoded := base64.RawURLEncoding.EncodeToString(signature)

	return &core.Claim{
		Type:      core.ClaimTypeUserLink,
		Data:      message,
		Signature: signatureEncoded,
		CreatedAt: time.Now(), // Keep for tracking purposes
	}, nil
}

// GenerateUnlinkClaim creates a signed claim for unlinking a platform user from their Gno address
func (w *UserLinkingWorkflowImpl) GenerateUnlinkClaim(platformID, gnoAddress string) (*core.Claim, error) {
	// Get current block height
	blockHeight, err := w.gnoClient.GetCurrentBlockHeight()
	if err != nil {
		return nil, fmt.Errorf("failed to get current block height: %w", err)
	}

	// Create message with block height and platformID only (no address needed for unlink)
	message := fmt.Sprintf("%d,%s", blockHeight, platformID)
	
	// Sign only the message (not the full signed message)
	signature := sign.Sign(nil, []byte(message), w.config.SigningKey)[:64] // Only the signature part
	signatureEncoded := base64.RawURLEncoding.EncodeToString(signature)

	return &core.Claim{
		Type:      core.ClaimTypeUserUnlink,
		Data:      message,
		Signature: signatureEncoded,
		CreatedAt: time.Now(), // Keep for tracking purposes
	}, nil
}

// GetLinkedAddress retrieves the Gno address linked to a platform user
func (w *UserLinkingWorkflowImpl) GetLinkedAddress(platformID string) (string, error) {
	return w.gnoClient.GetLinkedAddress(platformID)
}

// GetClaimURL returns the URL where users can submit their claim
func (w *UserLinkingWorkflowImpl) GetClaimURL(claim *core.Claim) string {
	// Parse the claim data to extract values
	parts := strings.Split(claim.Data, ",")
	if len(parts) < 2 {
		return "" // Invalid claim data
	}

	blockHeight := parts[0]
	discordID := parts[1]

	if claim.Type == core.ClaimTypeUserUnlink {
		// Unlink URL: /unlink?blockHeight=X&discordID=Y&signature=S
		return fmt.Sprintf("%s/%s:unlink?blockHeight=%s&discordID=%s&signature=%s",
			w.config.BaseURL, w.config.UserContract, blockHeight, discordID, claim.Signature)
	}

	// Link URL: /link?blockHeight=X&discordID=Y&address=Z&signature=S
	if len(parts) < 3 {
		return "" // Invalid claim data for link
	}
	address := parts[2]

	return fmt.Sprintf("%s/%s:link?blockHeight=%s&discordID=%s&address=%s&signature=%s",
		w.config.BaseURL, w.config.UserContract, blockHeight, discordID, address, claim.Signature)
}
