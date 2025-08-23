package indexer

import "encoding/json"

// EventAttribute represents a key-value pair in an event
type EventAttribute struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

// Event represents a blockchain event
type Event struct {
	Epoch     int64            `json:"epoch"`
	Timestamp int64            `json:"timestamp"`
	Height    int64            `json:"height"`
	TxIndex   int64            `json:"tx_index"`
	EventType string           `json:"event_type"`
	PkgPath   string           `json:"pkg_path"`
	Attrs     []EventAttribute `json:"attrs"`
}

// GnoEvent represents a Gno blockchain event
type GnoEvent struct {
	Type    string           `json:"type"`
	PkgPath string           `json:"pkg_path"`
	Attrs   []EventAttribute `json:"attrs"`
}

// TransactionResponse contains the events from a transaction
type TransactionResponse struct {
	Events []GnoEvent `json:"events"`
}

// Transaction represents a blockchain transaction with events
type Transaction struct {
	Hash        string              `json:"hash"`
	Index       int64               `json:"index"`
	BlockHeight int64               `json:"block_height"`
	Response    TransactionResponse `json:"response"`
}

// Block represents basic block information
type Block struct {
	Height    int64  `json:"height"`
	Hash      string `json:"hash"`
	Timestamp int64  `json:"timestamp"` // Unix timestamp
}

// BlockInfo contains both latest height and genesis block info
type BlockInfo struct {
	LatestHeight int64  `json:"latest_height"`
	Genesis      *Block `json:"genesis"`
}

// GraphQLResponse represents a generic GraphQL response
type GraphQLResponse struct {
	Data   json.RawMessage `json:"data"`
	Errors []GraphQLError  `json:"errors"`
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