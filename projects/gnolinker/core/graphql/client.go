package graphql

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// GraphQL WebSocket message types
const (
	MessageTypeConnectionInit = "connection_init"
	MessageTypeStart          = "start"
	MessageTypeStop           = "stop"
	MessageTypeConnectionAck  = "connection_ack"
	MessageTypeData           = "data"
	MessageTypeError          = "error"
	MessageTypeComplete       = "complete"
	MessageTypeKeepAlive      = "ka"
)

type WebSocketMessage struct {
	ID      string      `json:"id,omitempty"`
	Type    string      `json:"type"`
	Payload interface{} `json:"payload,omitempty"`
}

type GraphQLRequest struct {
	Query     string                 `json:"query"`
	Variables map[string]interface{} `json:"variables,omitempty"`
}

type Client struct {
	conn         *websocket.Conn
	url          string
	mu           sync.RWMutex
	writeMu      sync.Mutex // Separate mutex for WebSocket writes
	subscriptions map[string]chan struct{}
	handlers     map[string]func(any, error)
	connected    bool
}

func NewClient(url string) *Client {
	return &Client{
		url:           url,
		subscriptions: make(map[string]chan struct{}),
		handlers:      make(map[string]func(any, error)),
	}
}

func (c *Client) Connect(ctx context.Context) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.connected {
		return nil
	}

	u, err := url.Parse(c.url)
	if err != nil {
		return fmt.Errorf("failed to parse WebSocket URL: %w", err)
	}

	log.Printf("Connecting to GraphQL WebSocket: %s", u.String())
	conn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
	if err != nil {
		return fmt.Errorf("failed to connect to WebSocket: %w", err)
	}

	c.conn = conn
	c.connected = true

	// Start message reader
	go c.readMessages()

	// Send connection init
	initMsg := WebSocketMessage{
		Type: MessageTypeConnectionInit,
	}

	if err := c.sendMessage(initMsg); err != nil {
		return fmt.Errorf("failed to send connection init: %w", err)
	}

	log.Printf("GraphQL WebSocket connected successfully")
	return nil
}

func (c *Client) Subscribe(ctx context.Context, subscription any, variables map[string]any, handler func(any, error)) error {
	c.mu.RLock()
	if !c.connected {
		c.mu.RUnlock()
		return fmt.Errorf("client not connected")
	}
	c.mu.RUnlock()

	// Generate subscription ID
	subscriptionID := fmt.Sprintf("sub-%d", time.Now().UnixNano())

	// Create subscription message
	subscriptionMsg := WebSocketMessage{
		ID:   subscriptionID,
		Type: MessageTypeStart,
		Payload: GraphQLRequest{
			Query:     c.extractQuery(subscription),
			Variables: variables,
		},
	}

	log.Printf("Starting subscription with ID: %s", subscriptionID)

	// Add subscription to tracking
	c.mu.Lock()
	stopChan := make(chan struct{})
	c.subscriptions[subscriptionID] = stopChan
	c.handlers[subscriptionID] = handler
	c.mu.Unlock()

	// Send subscription
	if err := c.sendMessage(subscriptionMsg); err != nil {
		return fmt.Errorf("failed to send subscription: %w", err)
	}

	// Wait for context cancellation
	go func() {
		select {
		case <-ctx.Done():
			c.stopSubscription(subscriptionID)
		case <-stopChan:
		}
	}()

	return nil
}

func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn != nil {
		// Stop all subscriptions
		for id, stopChan := range c.subscriptions {
			close(stopChan)
			delete(c.subscriptions, id)
		}
		
		// Clear handlers
		c.handlers = make(map[string]func(any, error))

		// Close connection
		c.connected = false
		return c.conn.Close()
	}
	return nil
}

func (c *Client) ConnectWithRetry(ctx context.Context, maxRetries int, retryDelay time.Duration) error {
	for i := 0; i < maxRetries; i++ {
		if err := c.Connect(ctx); err != nil {
			if i == maxRetries-1 {
				return fmt.Errorf("failed to connect after %d retries: %w", maxRetries, err)
			}
			log.Printf("Connection attempt %d failed: %v. Retrying in %v...", i+1, err, retryDelay)
			time.Sleep(retryDelay)
			continue
		}
		log.Printf("Successfully connected to GraphQL endpoint")
		return nil
	}
	return fmt.Errorf("max retries exceeded")
}

func (c *Client) sendMessage(msg WebSocketMessage) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	log.Printf("📤 Sending GraphQL message: %s", string(data))
	
	// Use separate mutex for WebSocket writes to prevent concurrent writes
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	
	return c.conn.WriteMessage(websocket.TextMessage, data)
}

func (c *Client) readMessages() {
	defer func() {
		c.mu.Lock()
		c.connected = false
		c.mu.Unlock()
	}()

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			log.Printf("WebSocket read error: %v", err)
			return
		}

		log.Printf("📨 Received GraphQL message: %s", string(message))

		var msg WebSocketMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("Failed to unmarshal GraphQL message: %v", err)
			continue
		}

		c.handleMessage(msg)
	}
}

func (c *Client) handleMessage(msg WebSocketMessage) {
	switch msg.Type {
	case MessageTypeConnectionAck:
		log.Printf("✅ GraphQL WebSocket connection acknowledged")
	case MessageTypeKeepAlive:
		log.Printf("💓 GraphQL WebSocket keep-alive")
	case MessageTypeData:
		log.Printf("🎉 GraphQL data received for subscription %s: %+v", msg.ID, msg.Payload)
		
		c.mu.RLock()
		handler, exists := c.handlers[msg.ID]
		c.mu.RUnlock()
		
		if exists && handler != nil {
			// Parse payload as the subscription structure
			go handler(msg.Payload, nil)
		} else {
			log.Printf("No handler found for subscription %s", msg.ID)
		}
	case MessageTypeError:
		log.Printf("❌ GraphQL error for subscription %s: %+v", msg.ID, msg.Payload)
		
		c.mu.RLock()
		handler, exists := c.handlers[msg.ID]
		c.mu.RUnlock()
		
		if exists && handler != nil {
			go handler(nil, fmt.Errorf("GraphQL error: %+v", msg.Payload))
		}
	case MessageTypeComplete:
		log.Printf("✅ GraphQL subscription %s completed", msg.ID)
		c.stopSubscription(msg.ID)
	default:
		log.Printf("❓ Unknown GraphQL message type: %s", msg.Type)
	}
}

func (c *Client) stopSubscription(subscriptionID string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if stopChan, exists := c.subscriptions[subscriptionID]; exists {
		close(stopChan)
		delete(c.subscriptions, subscriptionID)
	}
	
	// Remove handler
	delete(c.handlers, subscriptionID)

	// Send stop message
	stopMsg := WebSocketMessage{
		ID:   subscriptionID,
		Type: MessageTypeStop,
	}

	if err := c.sendMessage(stopMsg); err != nil {
		log.Printf("Failed to send stop message for subscription %s: %v", subscriptionID, err)
	}
}

func (c *Client) extractQuery(subscription any) string {
	// Check the subscription type to determine the query
	switch subscription.(type) {
	case *UserLinkedEventsSubscription:
		return `subscription {
			transactions(filter: {events: {type: "UserLinked"}}) {
				hash
				block_height
				response {
					events {
						... on GnoEvent {
							type
							attrs {
								key
								value
							}
						}
					}
				}
			}
		}`
	case *UserUnlinkedEventsSubscription:
		return `subscription {
			transactions(filter: {events: {type: "UserUnlinked"}}) {
				hash
				block_height
				response {
					events {
						... on GnoEvent {
							type
							attrs {
								key
								value
							}
						}
					}
				}
			}
		}`
	default:
		// Default to all events for debugging
		return `subscription {
			transactions(filter: {}) {
				hash
				block_height
				response {
					events {
						... on GnoEvent {
							type
							attrs {
								key
								value
							}
						}
					}
				}
			}
		}`
	}
}
