package indexer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

// Client handles GraphQL queries for event fetching
type Client struct {
	url        string
	httpClient *http.Client
	logger     *slog.Logger
}

// NewClient creates a new GraphQL client
func NewClient(url string, logger *slog.Logger) *Client {
	// Convert WebSocket URL to HTTP URL if needed
	if strings.HasPrefix(url, "wss://") {
		url = "https://" + url[6:]
	} else if strings.HasPrefix(url, "ws://") {
		url = "http://" + url[5:]
	}

	// Create HTTP client with proper connection pooling and timeouts
	transport := &http.Transport{
		MaxIdleConns:          10,
		MaxIdleConnsPerHost:   10,
		IdleConnTimeout:       90 * time.Second,
		DisableKeepAlives:     false,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 10 * time.Second,
	}

	return &Client{
		url:    url,
		logger: logger,
		httpClient: &http.Client{
			Timeout:   30 * time.Second,
			Transport: transport,
		},
	}
}

// QueryEvents queries for events from specified packages
func (c *Client) QueryEvents(ctx context.Context, packages []string, eventFilter []string, afterHeight int64, afterTxIndex int64, latestHeight int64) ([]Transaction, error) {
	// Build package filter
	pkgFilter := ""
	if len(packages) == 1 {
		pkgFilter = fmt.Sprintf(`pkg_path: { eq: "%s" }`, packages[0])
	} else if len(packages) > 1 {
		pkgPaths := []string{}
		for _, pkg := range packages {
			pkgPaths = append(pkgPaths, fmt.Sprintf(`{ pkg_path: { eq: "%s" } }`, pkg))
		}
		pkgFilter = fmt.Sprintf(`_or: [%s]`, strings.Join(pkgPaths, ", "))
	}

	// Build event type filter
	eventTypeFilter := ""
	if len(eventFilter) > 0 {
		if len(eventFilter) == 1 {
			eventTypeFilter = fmt.Sprintf(`type: { eq: "%s" }`, eventFilter[0])
		} else {
			types := []string{}
			for _, evt := range eventFilter {
				types = append(types, fmt.Sprintf(`{ type: { eq: "%s" } }`, evt))
			}
			eventTypeFilter = fmt.Sprintf(`_or: [%s]`, strings.Join(types, ", "))
		}
	}

	// Combine filters for GnoEvent
	gnoEventFilter := pkgFilter
	if eventTypeFilter != "" {
		if gnoEventFilter != "" {
			gnoEventFilter = fmt.Sprintf(`_and: [{ %s }, { %s }]`, pkgFilter, eventTypeFilter)
		} else {
			gnoEventFilter = eventTypeFilter
		}
	}

	// Build height/index filter
	txIndex := afterTxIndex
	if txIndex <= 0 {
		txIndex = 0
	}

	whereClause := fmt.Sprintf(`_or: [
		{
			block_height: { gt: %d, lte: %d }
		},
		{
			block_height: { eq: %d }
			index: { gt: %d }
		}
	]`, afterHeight, latestHeight, afterHeight, txIndex)

	// Build the GraphQL query
	query := fmt.Sprintf(`
		query Events {
			getTransactions(
				where: {
					success: { eq: true }
					%s
					response: {
						events: {
							GnoEvent: {
								%s
							}
						}
					}
				}
				order: { heightAndIndex: ASC }
			) {
				hash
				index
				block_height
				response {
					events {
						... on GnoEvent {
							type
							pkg_path
							attrs {
								key
								value
							}
						}
					}
				}
			}
		}
	`, whereClause, gnoEventFilter)

	return c.executeQuery(ctx, query)
}

// QueryBlockInfo queries for both latest block height and genesis block in a single request
func (c *Client) QueryBlockInfo(ctx context.Context) (*BlockInfo, error) {
	query := `
		query BlockInfo {
			latestBlockHeight
			getBlocks(where: { height: { eq: 1 } }) {
				height
				hash
				timestamp
			}
		}
	`

	resp, err := c.execute(ctx, query)
	if err != nil {
		return nil, err
	}

	var result struct {
		LatestBlockHeight json.Number `json:"latestBlockHeight"`
		GetBlocks        []Block     `json:"getBlocks"`
	}
	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to unmarshal block info: %w", err)
	}

	height, err := result.LatestBlockHeight.Int64()
	if err != nil {
		return nil, fmt.Errorf("failed to parse latest block height: %w", err)
	}

	if len(result.GetBlocks) == 0 {
		return nil, fmt.Errorf("genesis block not found")
	}

	return &BlockInfo{
		LatestHeight: height,
		Genesis:      &result.GetBlocks[0],
	}, nil
}

// executeQuery executes a query and returns parsed transactions
func (c *Client) executeQuery(ctx context.Context, query string) ([]Transaction, error) {
	resp, err := c.execute(ctx, query)
	if err != nil {
		return nil, err
	}

	var result struct {
		GetTransactions []Transaction `json:"getTransactions"`
	}
	if err := json.Unmarshal(resp.Data, &result); err != nil {
		// Try old field name for backward compatibility
		var oldResult struct {
			Transactions []Transaction `json:"transactions"`
		}
		if err := json.Unmarshal(resp.Data, &oldResult); err != nil {
			return nil, fmt.Errorf("failed to unmarshal transactions: %w", err)
		}
		return oldResult.Transactions, nil
	}

	return result.GetTransactions, nil
}

// execute performs a GraphQL request with retry logic
func (c *Client) execute(ctx context.Context, query string) (*GraphQLResponse, error) {
	return c.executeWithRetry(ctx, query, 3)
}

func (c *Client) executeWithRetry(ctx context.Context, query string, maxRetries int) (*GraphQLResponse, error) {
	// Prepare query for HTTP request
	escapedQuery := strings.ReplaceAll(query, `"`, `\"`)
	escapedQuery = strings.ReplaceAll(escapedQuery, "\n", " ")
	escapedQuery = strings.ReplaceAll(escapedQuery, "\t", " ")
	escapedQuery = strings.Join(strings.Fields(escapedQuery), " ")
	queryString := fmt.Sprintf(`{"query": "%s"}`, escapedQuery)

	var lastErr error

	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			c.logger.Warn("Retrying GraphQL query",
				"attempt", attempt+1,
				"max_attempts", maxRetries+1,
				"previous_error", lastErr)
			
			// Exponential backoff
			backoff := time.Duration(attempt) * time.Second
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(backoff):
			}
		}

		c.logger.Debug("Executing GraphQL query",
			"url", c.url,
			"attempt", attempt+1)

		// Create HTTP request
		req, err := http.NewRequestWithContext(ctx, "POST", c.url, bytes.NewBufferString(queryString))
		if err != nil {
			return nil, fmt.Errorf("failed to create request: %w", err)
		}

		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json")

		// Make request
		resp, err := c.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("failed to execute request (attempt %d/%d): %w", attempt+1, maxRetries+1, err)
			if attempt < maxRetries {
				continue
			}
			return nil, lastErr
		}
		defer resp.Body.Close()

		// Check HTTP status
		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			lastErr = fmt.Errorf("GraphQL server returned HTTP %d: %s", resp.StatusCode, string(body))
			if attempt < maxRetries && (resp.StatusCode >= 500 || resp.StatusCode == 429) {
				continue // Retry on server errors and rate limiting
			}
			return nil, lastErr
		}

		// Read response
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			lastErr = fmt.Errorf("failed to read response body: %w", err)
			if attempt < maxRetries {
				continue
			}
			return nil, lastErr
		}

		// Parse GraphQL response
		var graphqlResp GraphQLResponse
		if err := json.Unmarshal(body, &graphqlResp); err != nil {
			lastErr = fmt.Errorf("failed to parse GraphQL response: %w", err)
			if attempt < maxRetries {
				continue
			}
			return nil, lastErr
		}

		// Check for GraphQL errors
		if len(graphqlResp.Errors) > 0 {
			return nil, fmt.Errorf("GraphQL error: %s", graphqlResp.Errors[0].Message)
		}

		return &graphqlResp, nil
	}

	return nil, lastErr
}