package abci

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
)

// ABCIInfo represents the ABCI info response
type ABCIInfo struct {
	Jsonrpc string      `json:"jsonrpc"`
	ID      string      `json:"id"`
	Result  ABCIResult  `json:"result"`
	Error   *ABCIError  `json:"error,omitempty"`
}

// ABCIResult represents the result part of ABCI info response
type ABCIResult struct {
	Response ABCIResponse `json:"response"`
}

// ABCIResponse represents the ABCI response data
type ABCIResponse struct {
	Data                 string `json:"data"`
	Version              string `json:"version"`
	AppVersion           string `json:"app_version"`
	LastBlockHeight      string `json:"last_block_height"`
	LastBlockAppHash     string `json:"last_block_app_hash"`
}

// ABCIError represents an error in the ABCI response
type ABCIError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    string `json:"data,omitempty"`
}

// Client handles ABCI info requests
type Client struct {
	url        string
	httpClient *http.Client
	logger     core.Logger
}

// NewClient creates a new ABCI client
func NewClient(url string, logger core.Logger) *Client {
	return &Client{
		url: url,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		logger: logger,
	}
}

// GetInfo retrieves ABCI info from the node
func (c *Client) GetInfo(ctx context.Context) (*ABCIInfo, error) {
	// Create the JSON-RPC request
	requestBody := map[string]interface{}{
		"jsonrpc": "2.0",
		"method":  "abci_info",
		"params":  []interface{}{},
		"id":      "1",
	}

	reqBytes, err := json.Marshal(requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Create HTTP request
	req, err := http.NewRequestWithContext(ctx, "POST", c.url, bytes.NewBuffer(reqBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	// Make the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Check HTTP status
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP error: %d - %s", resp.StatusCode, string(body))
	}

	// Parse response
	var abciInfo ABCIInfo
	if err := json.Unmarshal(body, &abciInfo); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	// Check for RPC error
	if abciInfo.Error != nil {
		return nil, fmt.Errorf("RPC error: %d - %s", abciInfo.Error.Code, abciInfo.Error.Message)
	}

	return &abciInfo, nil
}

// GetLatestBlockHeight retrieves the latest block height from the node
func (c *Client) GetLatestBlockHeight(ctx context.Context) (int64, error) {
	info, err := c.GetInfo(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to get ABCI info: %w", err)
	}

	// Parse the last block height
	var height int64
	if _, err := fmt.Sscanf(info.Result.Response.LastBlockHeight, "%d", &height); err != nil {
		return 0, fmt.Errorf("failed to parse block height '%s': %w", info.Result.Response.LastBlockHeight, err)
	}

	c.logger.Debug("Retrieved latest block height", "height", height)
	return height, nil
}

// GetLatestBlockHeightWithRetry retrieves the latest block height with retry logic
func (c *Client) GetLatestBlockHeightWithRetry(ctx context.Context, maxRetries int) (int64, error) {
	var lastErr error
	
	for i := 0; i < maxRetries; i++ {
		height, err := c.GetLatestBlockHeight(ctx)
		if err == nil {
			return height, nil
		}
		
		lastErr = err
		c.logger.Warn("Failed to get block height, retrying", "attempt", i+1, "max_retries", maxRetries, "error", err)
		
		// Wait before retry (exponential backoff)
		if i < maxRetries-1 {
			waitTime := time.Duration(i+1) * time.Second
			select {
			case <-ctx.Done():
				return 0, ctx.Err()
			case <-time.After(waitTime):
			}
		}
	}
	
	return 0, fmt.Errorf("failed to get block height after %d retries: %w", maxRetries, lastErr)
}

// HealthCheck verifies that the ABCI endpoint is reachable
func (c *Client) HealthCheck(ctx context.Context) error {
	_, err := c.GetInfo(ctx)
	if err != nil {
		return fmt.Errorf("ABCI health check failed: %w", err)
	}
	
	c.logger.Info("ABCI health check passed")
	return nil
}