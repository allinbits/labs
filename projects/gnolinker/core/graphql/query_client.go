package graphql

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
)

// RealmConfig holds the configurable realm paths
type RealmConfig struct {
	UserRealmPath string
	RoleRealmPath string
}

// QueryClient handles regular GraphQL queries (not subscriptions)
type QueryClient struct {
	url         string
	httpClient  *http.Client
	realmConfig RealmConfig
	logger      core.Logger
}

// GraphQLResponse represents a GraphQL response
type GraphQLResponse struct {
	Data   map[string]any `json:"data"`
	Errors []GraphQLError `json:"errors"`
}

// GraphQLError represents a GraphQL error
type GraphQLError struct {
	Message   string `json:"message"`
	Locations []struct {
		Line   int `json:"line"`
		Column int `json:"column"`
	} `json:"locations"`
	Extensions map[string]any `json:"extensions"`
}

// NewQueryClient creates a new GraphQL query client
func NewQueryClient(url string, realmConfig RealmConfig) *QueryClient {
	// Convert WebSocket URL to HTTP URL if needed
	if strings.HasPrefix(url, "wss://") {
		url = "https://" + url[6:]
	} else if strings.HasPrefix(url, "ws://") {
		url = "http://" + url[5:]
	}
	
	// Create HTTP client with proper connection pooling and timeouts
	transport := &http.Transport{
		MaxIdleConns:        10,
		MaxIdleConnsPerHost: 10,
		IdleConnTimeout:     90 * time.Second,
		DisableKeepAlives:   false, // Enable keep-alives
		TLSHandshakeTimeout: 10 * time.Second,
		ResponseHeaderTimeout: 10 * time.Second,
	}
	
	// Create a logger for the query client
	logger := core.NewSlogLogger(core.ParseLogLevel("info"))
	
	return &QueryClient{
		url:         url,
		realmConfig: realmConfig,
		logger:      logger,
		httpClient: &http.Client{
			Timeout:   30 * time.Second,
			Transport: transport,
		},
	}
}


// QueryUserEvents queries for all user events (UserLinked and UserUnlinked) in chronological order
func (qc *QueryClient) QueryUserEvents(ctx context.Context, afterBlockHeight int64, afterTxIndex int64, latestBlockHeight int64) ([]Transaction, error) {
	
	// Set index to 0 if not greater than 0
	txIndex := afterTxIndex
	if txIndex <= 0 {
		txIndex = 0
	}
	
	whereClause := fmt.Sprintf(`_or: [
			{
				block_height: { gt: %d, lt: %d }
			},
			{
				block_height: { eq: %d }
				index: { gt: %d }
			}
		]`, afterBlockHeight, latestBlockHeight, afterBlockHeight, txIndex)

	// Build the GraphQL query in readable format
	query := fmt.Sprintf(`
		query UserEvents {
			getTransactions(
				where: {
					success: { eq: true }
					%s
					response: {
						events: {
							GnoEvent: {
								pkg_path: { eq: "%s" }
							}
						}
					}
				}
				order: { heightAndIndex: ASC }
			) {
				hash
				index
				block_height
				messages {
					value {
						... on MsgCall {
							func
						}
					}
				}
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
	`, whereClause, qc.realmConfig.UserRealmPath)

	// Convert to single-line JSON for HTTP request, properly escaping quotes and whitespace
	escapedQuery := strings.ReplaceAll(query, `"`, `\"`)
	escapedQuery = strings.ReplaceAll(escapedQuery, "\n", " ")
	escapedQuery = strings.ReplaceAll(escapedQuery, "\t", " ")
	// Remove extra spaces
	escapedQuery = strings.Join(strings.Fields(escapedQuery), " ")
	queryString := fmt.Sprintf(`{"query": "%s"}`, escapedQuery)

	qc.logger.Debug("Executing UserEvents query", "from_block", afterBlockHeight, "from_tx_index", afterTxIndex, "readable_query", query)
	return qc.executeQuery(ctx, queryString)
}


// QueryRoleEvents queries for all role events (RoleLinked and RoleUnlinked) in chronological order
func (qc *QueryClient) QueryRoleEvents(ctx context.Context, afterBlockHeight int64, afterTxIndex int64, latestBlockHeight int64) ([]Transaction, error) {
	
	// Set index to 0 if not greater than 0
	txIndex := afterTxIndex
	if txIndex <= 0 {
		txIndex = 0
	}
	
	whereClause := fmt.Sprintf(`_or: [
			{
				block_height: { gt: %d, lt: %d }
			},
			{
				block_height: { eq: %d }
				index: { gt: %d }
			}
		]`, afterBlockHeight, latestBlockHeight, afterBlockHeight, txIndex)

	// Build the GraphQL query in readable format
	query := fmt.Sprintf(`
		query RoleEvents {
			getTransactions(
				where: {
					success: { eq: true }
					%s
					response: {
						events: {
							GnoEvent: {
								pkg_path: { eq: "%s" }
							}
						}
					}
				}
				order: { heightAndIndex: ASC }
			) {
				hash
				index
				block_height
				messages {
					value {
						... on MsgCall {
							func
						}
					}
				}
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
	`, whereClause, qc.realmConfig.RoleRealmPath)

	// Convert to single-line JSON for HTTP request, properly escaping quotes and whitespace
	escapedQuery := strings.ReplaceAll(query, `"`, `\"`)
	escapedQuery = strings.ReplaceAll(escapedQuery, "\n", " ")
	escapedQuery = strings.ReplaceAll(escapedQuery, "\t", " ")
	// Remove extra spaces
	escapedQuery = strings.Join(strings.Fields(escapedQuery), " ")
	queryString := fmt.Sprintf(`{"query": "%s"}`, escapedQuery)

	qc.logger.Debug("Executing RoleEvents query", "from_block", afterBlockHeight, "from_tx_index", afterTxIndex, "readable_query", query)
	return qc.executeQuery(ctx, queryString)
}


// executeQuery executes a GraphQL query and returns parsed transactions
func (qc *QueryClient) executeQuery(ctx context.Context, queryString string) ([]Transaction, error) {
	return qc.executeQueryWithRetry(ctx, queryString, 3)
}

// executeQueryWithRetry executes a GraphQL query with retry logic
func (qc *QueryClient) executeQueryWithRetry(ctx context.Context, queryString string, maxRetries int) ([]Transaction, error) {
	var lastErr error
	
	qc.logger.Debug("Executing GraphQL query", "url", qc.url, "max_retries", maxRetries)
	
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			qc.logger.Warn("Retrying GraphQL query", "attempt", attempt+1, "max_attempts", maxRetries+1, "previous_error", lastErr)
			// Wait before retrying (exponential backoff)
			backoff := time.Duration(attempt) * time.Second
			select {
			case <-ctx.Done():
				qc.logger.Error("GraphQL query cancelled", "error", ctx.Err())
				return nil, ctx.Err()
			case <-time.After(backoff):
			}
		}
		
		// Log the query being sent for debugging
		qc.logger.Debug("Sending GraphQL query", "url", qc.url, "query", queryString, "attempt", attempt+1)
		
		// Create HTTP request
		req, err := http.NewRequestWithContext(ctx, "POST", qc.url, bytes.NewBufferString(queryString))
		if err != nil {
			return nil, fmt.Errorf("failed to create request: %w", err)
		}

		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json")

		// Make request
		resp, err := qc.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("failed to execute request (attempt %d/%d): %w", attempt+1, maxRetries+1, err)
			qc.logger.Error("GraphQL request failed", "attempt", attempt+1, "error", err, "url", qc.url)
			if attempt < maxRetries {
				continue // Retry on network errors
			}
			return nil, lastErr
		}
		defer resp.Body.Close()
		
		// Check HTTP status code
		if resp.StatusCode != http.StatusOK {
			// Read error response body for more details
			errorBody, bodyErr := io.ReadAll(resp.Body)
			if bodyErr == nil && len(errorBody) > 0 {
				qc.logger.Error("GraphQL server error with body", "status_code", resp.StatusCode, "status", resp.Status, "url", qc.url, "error_body", string(errorBody))
				lastErr = fmt.Errorf("GraphQL server returned HTTP %d: %s, body: %s", resp.StatusCode, resp.Status, string(errorBody))
			} else {
				qc.logger.Error("GraphQL server error", "status_code", resp.StatusCode, "status", resp.Status, "url", qc.url)
				lastErr = fmt.Errorf("GraphQL server returned HTTP %d: %s", resp.StatusCode, resp.Status)
			}
			if attempt < maxRetries && (resp.StatusCode >= 500 || resp.StatusCode == 429) {
				continue // Retry on server errors and rate limiting
			}
			return nil, lastErr
		}

		// Read response
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			lastErr = fmt.Errorf("failed to read response body: %w", err)
			qc.logger.Error("Failed to read GraphQL response", "error", err, "attempt", attempt+1)
			if attempt < maxRetries {
				continue // Retry on read errors
			}
			return nil, lastErr
		}

		// Parse GraphQL response
		var graphqlResp GraphQLResponse
		if err := json.Unmarshal(body, &graphqlResp); err != nil {
			lastErr = fmt.Errorf("failed to parse GraphQL response: %w", err)
			if attempt < maxRetries {
				continue // Retry on parse errors
			}
			return nil, lastErr
		}

		// Check for GraphQL errors
		if len(graphqlResp.Errors) > 0 {
			return nil, fmt.Errorf("GraphQL error: %s", graphqlResp.Errors[0].Message)
		}

		// Extract transactions from response - try both field names for compatibility
		transactionsData, ok := graphqlResp.Data["getTransactions"]
		if !ok {
			// Fallback to old field name for backward compatibility
			transactionsData, ok = graphqlResp.Data["transactions"]
			if !ok {
				return nil, fmt.Errorf("no getTransactions or transactions field in response")
			}
		}

		// Convert to our Transaction struct
		transactionsJSON, err := json.Marshal(transactionsData)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal transactions: %w", err)
		}

		var transactions []Transaction
		if err := json.Unmarshal(transactionsJSON, &transactions); err != nil {
			return nil, fmt.Errorf("failed to unmarshal transactions: %w", err)
		}

		return transactions, nil
	}
	
	return nil, lastErr
}

// QueryLatestBlockHeight queries the indexer for its latest processed block height
func (qc *QueryClient) QueryLatestBlockHeight(ctx context.Context) (int64, error) {
	return qc.queryLatestBlockHeightWithRetry(ctx, 3)
}

// queryLatestBlockHeightWithRetry queries the latest block height with retry logic
func (qc *QueryClient) queryLatestBlockHeightWithRetry(ctx context.Context, maxRetries int) (int64, error) {
	queryString := `{"query": "query LatestBlock { latestBlockHeight }"}`
	
	var lastErr error
	
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			// Wait before retrying (exponential backoff)
			backoff := time.Duration(attempt) * time.Second
			select {
			case <-ctx.Done():
				return 0, ctx.Err()
			case <-time.After(backoff):
			}
		}

		// Create HTTP request
		req, err := http.NewRequestWithContext(ctx, "POST", qc.url, bytes.NewBufferString(queryString))
		if err != nil {
			return 0, fmt.Errorf("failed to create request: %w", err)
		}

		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json")

		// Make request
		resp, err := qc.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("failed to execute request (attempt %d/%d): %w", attempt+1, maxRetries+1, err)
			if attempt < maxRetries {
				continue // Retry on network errors
			}
			return 0, lastErr
		}
		defer resp.Body.Close()

		// Read response
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			lastErr = fmt.Errorf("failed to read response body: %w", err)
			if attempt < maxRetries {
				continue // Retry on read errors
			}
			return 0, lastErr
		}

		// Parse GraphQL response
		var graphqlResp GraphQLResponse
		if err := json.Unmarshal(body, &graphqlResp); err != nil {
			lastErr = fmt.Errorf("failed to parse GraphQL response: %w", err)
			if attempt < maxRetries {
				continue // Retry on parse errors
			}
			return 0, lastErr
		}

		// Check for GraphQL errors
		if len(graphqlResp.Errors) > 0 {
			return 0, fmt.Errorf("GraphQL error: %s", graphqlResp.Errors[0].Message)
		}

		// Extract latestBlockHeight from response
		latestBlockHeight, ok := graphqlResp.Data["latestBlockHeight"]
		if !ok {
			return 0, fmt.Errorf("no latestBlockHeight field in response")
		}

		// Convert to int64
		switch v := latestBlockHeight.(type) {
		case float64:
			return int64(v), nil
		case int64:
			return v, nil
		case string:
			if height, err := strconv.ParseInt(v, 10, 64); err == nil {
				return height, nil
			}
			return 0, fmt.Errorf("failed to parse latestBlockHeight string: %s", v)
		default:
			return 0, fmt.Errorf("unexpected type for latestBlockHeight: %T", v)
		}
	}
	
	return 0, lastErr
}