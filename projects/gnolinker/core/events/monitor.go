package events

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/graphql"
)

type EventType string

const (
	UserLinkedEvent   EventType = "UserLinked"
	UserUnlinkedEvent EventType = "UserUnlinked"
	RoleLinkedEvent   EventType = "RoleLinked"
	RoleUnlinkedEvent EventType = "RoleUnlinked"
)

type Event struct {
	Type            EventType
	TransactionHash string
	BlockHeight     int64
	UserLinked      *graphql.UserLinkedEvent
	UserUnlinked    *graphql.UserUnlinkedEvent
	RoleLinked      *graphql.RoleLinkedEvent
	RoleUnlinked    *graphql.RoleUnlinkedEvent
}

type EventHandler func(event Event) error

type Monitor struct {
	client          *graphql.Client
	handlers        map[EventType][]EventHandler
	processedTxs    map[string]bool
	lastBlockHeight int64
	mu              sync.RWMutex
	logger          core.Logger
	ctx             context.Context
	cancel          context.CancelFunc
}

func NewMonitor(graphqlEndpoint string, logger core.Logger) *Monitor {
	return &Monitor{
		client:       graphql.NewClient(graphqlEndpoint),
		handlers:     make(map[EventType][]EventHandler),
		processedTxs: make(map[string]bool),
		logger:       logger,
	}
}

func (m *Monitor) AddHandler(eventType EventType, handler EventHandler) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.handlers[eventType] = append(m.handlers[eventType], handler)
}

func (m *Monitor) Start(ctx context.Context) error {
	m.ctx, m.cancel = context.WithCancel(ctx)

	if err := m.client.ConnectWithRetry(m.ctx, 5, 5*time.Second); err != nil {
		return fmt.Errorf("failed to connect to GraphQL endpoint: %w", err)
	}

	m.logger.Info("Event monitor connected to GraphQL endpoint")

	go m.startEventSubscription()

	return nil
}

func (m *Monitor) Stop() error {
	if m.cancel != nil {
		m.cancel()
	}
	return m.client.Close()
}

func (m *Monitor) startEventSubscription() {
	m.logger.Info("Starting GraphQL subscriptions for all events")

	// Start debug subscription to see ALL events
	go m.subscribeToAllEvents()
	
	// Start all subscriptions concurrently - writeMu will handle synchronization
	go m.subscribeToUserLinked()
	go m.subscribeToUserUnlinked()
	go m.subscribeToRoleLinked()
	go m.subscribeToRoleUnlinked()
}

func (m *Monitor) subscribeToUserLinked() {
	subscription := graphql.UserLinkedEventsSubscription{}

	m.logger.Info("Starting UserLinked subscription")

	variables := map[string]any{
		"filter": map[string]any{
			"events": map[string]any{
				"type": "UserLinked",
			},
		},
	}

	m.logger.Debug("UserLinked subscription variables", "variables", variables)

	err := m.client.Subscribe(m.ctx, &subscription, variables, m.handleUserLinkedData)
	if err != nil {
		m.logger.Error("UserLinked subscription error", "error", err)
	} else {
		m.logger.Info("UserLinked subscription started successfully")
	}
}

func (m *Monitor) subscribeToUserUnlinked() {
	subscription := graphql.UserUnlinkedEventsSubscription{}

	m.logger.Info("Starting UserUnlinked subscription")

	variables := map[string]any{
		"filter": map[string]any{
			"events": map[string]any{
				"type": "UserUnlinked",
			},
		},
	}

	m.logger.Debug("UserUnlinked subscription variables", "variables", variables)

	err := m.client.Subscribe(m.ctx, &subscription, variables, m.handleUserUnlinkedData)
	if err != nil {
		m.logger.Error("UserUnlinked subscription error", "error", err)
	} else {
		m.logger.Info("UserUnlinked subscription started successfully")
	}
}

func (m *Monitor) handleUserLinkedData(data any, err error) {
	if err != nil {
		m.logger.Error("UserLinked subscription data error", "error", err)
		return
	}

	m.logger.Debug("Raw UserLinked subscription data received", "data", data)

	subscription, ok := data.(*graphql.UserLinkedEventsSubscription)
	if !ok {
		m.logger.Error("Invalid UserLinked subscription data type", "actual_type", fmt.Sprintf("%T", data))
		return
	}

	m.logger.Info("Received UserLinked subscription data", "transaction_count", len(subscription.Transactions))

	for _, tx := range subscription.Transactions {
		m.logger.Info("Processing UserLinked transaction", "hash", tx.Hash, "block_height", tx.BlockHeight, "events_count", len(tx.Response.Events))

		if m.isProcessed(tx.Hash) {
			m.logger.Debug("UserLinked transaction already processed, skipping", "hash", tx.Hash)
			continue
		}

		m.processTransactionForUserLinked(tx)
		m.markProcessed(tx.Hash)

		if tx.BlockHeight > m.lastBlockHeight {
			m.lastBlockHeight = tx.BlockHeight
		}
	}
}

func (m *Monitor) handleUserUnlinkedData(data any, err error) {
	if err != nil {
		m.logger.Error("UserUnlinked subscription data error", "error", err)
		return
	}

	m.logger.Debug("Raw UserUnlinked subscription data received", "data", data)

	subscription, ok := data.(*graphql.UserUnlinkedEventsSubscription)
	if !ok {
		m.logger.Error("Invalid UserUnlinked subscription data type", "actual_type", fmt.Sprintf("%T", data))
		return
	}

	m.logger.Info("Received UserUnlinked subscription data", "transaction_count", len(subscription.Transactions))

	for _, tx := range subscription.Transactions {
		m.logger.Info("Processing UserUnlinked transaction", "hash", tx.Hash, "block_height", tx.BlockHeight, "events_count", len(tx.Response.Events))

		if m.isProcessed(tx.Hash) {
			m.logger.Debug("UserUnlinked transaction already processed, skipping", "hash", tx.Hash)
			continue
		}

		m.processTransactionForUserUnlinked(tx)
		m.markProcessed(tx.Hash)

		if tx.BlockHeight > m.lastBlockHeight {
			m.lastBlockHeight = tx.BlockHeight
		}
	}
}

func (m *Monitor) processTransactionForUserLinked(tx graphql.Transaction) {
	m.logger.Info("Processing UserLinked transaction events", "hash", tx.Hash, "events_count", len(tx.Response.Events))

	for i, event := range tx.Response.Events {
		m.logger.Info("Processing UserLinked event", "index", i, "type", event.Type, "attrs_count", len(event.Attrs))

		// Log event attributes for debugging
		for j, attr := range event.Attrs {
			m.logger.Debug("UserLinked event attribute", "event_type", event.Type, "attr_index", j, "key", attr.Key, "value", attr.Value)
		}

		if event.Type == "UserLinked" {
			m.logger.Info("Found UserLinked event", "tx_hash", tx.Hash)
			if userLinked, err := graphql.ParseUserLinkedEvent(event); err == nil {
				m.logger.Info("Successfully parsed UserLinked event", "address", userLinked.Address, "discord_id", userLinked.DiscordID)
				m.handleEvent(Event{
					Type:            UserLinkedEvent,
					TransactionHash: tx.Hash,
					BlockHeight:     tx.BlockHeight,
					UserLinked:      userLinked,
				})
			} else {
				m.logger.Error("Failed to parse UserLinked event", "error", err)
			}
		} else {
			m.logger.Debug("Ignoring non-UserLinked event type", "type", event.Type)
		}
	}
}

func (m *Monitor) processTransactionForUserUnlinked(tx graphql.Transaction) {
	m.logger.Info("Processing UserUnlinked transaction events", "hash", tx.Hash, "events_count", len(tx.Response.Events))

	for i, event := range tx.Response.Events {
		m.logger.Info("Processing UserUnlinked event", "index", i, "type", event.Type, "attrs_count", len(event.Attrs))

		// Log event attributes for debugging
		for j, attr := range event.Attrs {
			m.logger.Debug("UserUnlinked event attribute", "event_type", event.Type, "attr_index", j, "key", attr.Key, "value", attr.Value)
		}

		if event.Type == "UserUnlinked" {
			m.logger.Info("Found UserUnlinked event", "tx_hash", tx.Hash)
			if userUnlinked, err := graphql.ParseUserUnlinkedEvent(event); err == nil {
				m.logger.Info("Successfully parsed UserUnlinked event", "address", userUnlinked.Address, "discord_id", userUnlinked.DiscordID, "triggered_by", userUnlinked.TriggeredBy)
				m.handleEvent(Event{
					Type:            UserUnlinkedEvent,
					TransactionHash: tx.Hash,
					BlockHeight:     tx.BlockHeight,
					UserUnlinked:    userUnlinked,
				})
			} else {
				m.logger.Error("Failed to parse UserUnlinked event", "error", err)
			}
		} else {
			m.logger.Debug("Ignoring non-UserUnlinked event type", "type", event.Type)
		}
	}
}

func (m *Monitor) handleEvent(event Event) {
	m.mu.RLock()
	handlers := m.handlers[event.Type]
	m.mu.RUnlock()

	m.logger.Info("Handling event", "event_type", event.Type, "tx_hash", event.TransactionHash, "handler_count", len(handlers))

	for i, handler := range handlers {
		m.logger.Debug("Calling event handler", "handler_index", i, "event_type", event.Type)
		if err := handler(event); err != nil {
			m.logger.Error("Event handler error",
				"event_type", event.Type,
				"tx_hash", event.TransactionHash,
				"handler_index", i,
				"error", err,
			)
		} else {
			m.logger.Info("Event handler completed successfully", "handler_index", i, "event_type", event.Type)
		}
	}
}

func (m *Monitor) isProcessed(txHash string) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.processedTxs[txHash]
}

func (m *Monitor) markProcessed(txHash string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.processedTxs[txHash] = true

	if len(m.processedTxs) > 10000 {
		for hash := range m.processedTxs {
			delete(m.processedTxs, hash)
			if len(m.processedTxs) <= 5000 {
				break
			}
		}
	}
}

func (m *Monitor) GetLastBlockHeight() int64 {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.lastBlockHeight
}

func (m *Monitor) subscribeToAllEvents() {
	subscription := graphql.UserLinkedEventsSubscription{}

	m.logger.Info("Starting ALL EVENTS subscription for debugging")

	// No filter - get ALL events
	variables := map[string]any{
		"filter": map[string]any{},
	}

	m.logger.Debug("ALL EVENTS subscription variables", "variables", variables)

	err := m.client.Subscribe(m.ctx, &subscription, variables, m.handleAllEventsData)
	if err != nil {
		m.logger.Error("ALL EVENTS subscription error", "error", err)
	} else {
		m.logger.Info("ALL EVENTS subscription started successfully")
	}
}

func (m *Monitor) subscribeToRoleLinked() {
	subscription := graphql.UserLinkedEventsSubscription{} // Reusing same struct

	m.logger.Info("Starting RoleLinked subscription")

	variables := map[string]any{
		"filter": map[string]any{
			"events": map[string]any{
				"type": "RoleLinked",
			},
		},
	}

	m.logger.Debug("RoleLinked subscription variables", "variables", variables)

	err := m.client.Subscribe(m.ctx, &subscription, variables, m.handleRoleLinkedData)
	if err != nil {
		m.logger.Error("RoleLinked subscription error", "error", err)
	} else {
		m.logger.Info("RoleLinked subscription started successfully")
	}
}

func (m *Monitor) subscribeToRoleUnlinked() {
	subscription := graphql.UserLinkedEventsSubscription{} // Reusing same struct

	m.logger.Info("Starting RoleUnlinked subscription")

	variables := map[string]any{
		"filter": map[string]any{
			"events": map[string]any{
				"type": "RoleUnlinked",
			},
		},
	}

	m.logger.Debug("RoleUnlinked subscription variables", "variables", variables)

	err := m.client.Subscribe(m.ctx, &subscription, variables, m.handleRoleUnlinkedData)
	if err != nil {
		m.logger.Error("RoleUnlinked subscription error", "error", err)
	} else {
		m.logger.Info("RoleUnlinked subscription started successfully")
	}
}

func (m *Monitor) handleRoleLinkedData(data any, err error) {
	if err != nil {
		m.logger.Error("RoleLinked subscription data error", "error", err)
		return
	}

	m.logger.Debug("Raw RoleLinked subscription data received", "data", data)

	subscription, ok := data.(*graphql.UserLinkedEventsSubscription)
	if !ok {
		m.logger.Error("Invalid RoleLinked subscription data type", "actual_type", fmt.Sprintf("%T", data))
		return
	}

	m.logger.Info("Received RoleLinked subscription data", "transaction_count", len(subscription.Transactions))

	for _, tx := range subscription.Transactions {
		m.logger.Info("Processing RoleLinked transaction", "hash", tx.Hash, "block_height", tx.BlockHeight, "events_count", len(tx.Response.Events))

		if m.isProcessed(tx.Hash) {
			m.logger.Debug("RoleLinked transaction already processed, skipping", "hash", tx.Hash)
			continue
		}

		m.processTransactionForRoleLinked(tx)
		m.markProcessed(tx.Hash)

		if tx.BlockHeight > m.lastBlockHeight {
			m.lastBlockHeight = tx.BlockHeight
		}
	}
}

func (m *Monitor) handleRoleUnlinkedData(data any, err error) {
	if err != nil {
		m.logger.Error("RoleUnlinked subscription data error", "error", err)
		return
	}

	m.logger.Debug("Raw RoleUnlinked subscription data received", "data", data)

	subscription, ok := data.(*graphql.UserLinkedEventsSubscription)
	if !ok {
		m.logger.Error("Invalid RoleUnlinked subscription data type", "actual_type", fmt.Sprintf("%T", data))
		return
	}

	m.logger.Info("Received RoleUnlinked subscription data", "transaction_count", len(subscription.Transactions))

	for _, tx := range subscription.Transactions {
		m.logger.Info("Processing RoleUnlinked transaction", "hash", tx.Hash, "block_height", tx.BlockHeight, "events_count", len(tx.Response.Events))

		if m.isProcessed(tx.Hash) {
			m.logger.Debug("RoleUnlinked transaction already processed, skipping", "hash", tx.Hash)
			continue
		}

		m.processTransactionForRoleUnlinked(tx)
		m.markProcessed(tx.Hash)

		if tx.BlockHeight > m.lastBlockHeight {
			m.lastBlockHeight = tx.BlockHeight
		}
	}
}

func (m *Monitor) processTransactionForRoleLinked(tx graphql.Transaction) {
	m.logger.Info("Processing RoleLinked transaction events", "hash", tx.Hash, "events_count", len(tx.Response.Events))

	for i, event := range tx.Response.Events {
		m.logger.Info("Processing RoleLinked event", "index", i, "type", event.Type, "attrs_count", len(event.Attrs))

		// Log event attributes for debugging
		for j, attr := range event.Attrs {
			m.logger.Debug("RoleLinked event attribute", "event_type", event.Type, "attr_index", j, "key", attr.Key, "value", attr.Value)
		}

		if event.Type == "RoleLinked" {
			m.logger.Info("Found RoleLinked event", "tx_hash", tx.Hash)
			if roleLinked, err := graphql.ParseRoleLinkedEvent(event); err == nil {
				m.logger.Info("Successfully parsed RoleLinked event", "realm_path", roleLinked.RealmPath, "role_name", roleLinked.RoleName, "discord_guild_id", roleLinked.DiscordGuildID, "discord_role_id", roleLinked.DiscordRoleID)
				m.handleEvent(Event{
					Type:            RoleLinkedEvent,
					TransactionHash: tx.Hash,
					BlockHeight:     tx.BlockHeight,
					RoleLinked:      roleLinked,
				})
			} else {
				m.logger.Error("Failed to parse RoleLinked event", "error", err)
			}
		} else {
			m.logger.Debug("Ignoring non-RoleLinked event type", "type", event.Type)
		}
	}
}

func (m *Monitor) processTransactionForRoleUnlinked(tx graphql.Transaction) {
	m.logger.Info("Processing RoleUnlinked transaction events", "hash", tx.Hash, "events_count", len(tx.Response.Events))

	for i, event := range tx.Response.Events {
		m.logger.Info("Processing RoleUnlinked event", "index", i, "type", event.Type, "attrs_count", len(event.Attrs))

		// Log event attributes for debugging
		for j, attr := range event.Attrs {
			m.logger.Debug("RoleUnlinked event attribute", "event_type", event.Type, "attr_index", j, "key", attr.Key, "value", attr.Value)
		}

		if event.Type == "RoleUnlinked" {
			m.logger.Info("Found RoleUnlinked event", "tx_hash", tx.Hash)
			if roleUnlinked, err := graphql.ParseRoleUnlinkedEvent(event); err == nil {
				m.logger.Info("Successfully parsed RoleUnlinked event", "realm_path", roleUnlinked.RealmPath, "role_name", roleUnlinked.RoleName, "discord_guild_id", roleUnlinked.DiscordGuildID, "discord_role_id", roleUnlinked.DiscordRoleID)
				m.handleEvent(Event{
					Type:            RoleUnlinkedEvent,
					TransactionHash: tx.Hash,
					BlockHeight:     tx.BlockHeight,
					RoleUnlinked:    roleUnlinked,
				})
			} else {
				m.logger.Error("Failed to parse RoleUnlinked event", "error", err)
			}
		} else {
			m.logger.Debug("Ignoring non-RoleUnlinked event type", "type", event.Type)
		}
	}
}

func (m *Monitor) handleAllEventsData(data any, err error) {
	if err != nil {
		m.logger.Error("ALL EVENTS subscription data error", "error", err)
		return
	}

	m.logger.Debug("ALL EVENTS: Raw subscription data received", "data", data)

	subscription, ok := data.(*graphql.UserLinkedEventsSubscription)
	if !ok {
		m.logger.Error("ALL EVENTS: Invalid subscription data type", "actual_type", fmt.Sprintf("%T", data))
		return
	}

	m.logger.Debug("ALL EVENTS: Received subscription data", "transaction_count", len(subscription.Transactions))

	for _, tx := range subscription.Transactions {
		m.logger.Debug("ALL EVENTS: Processing transaction", "hash", tx.Hash, "block_height", tx.BlockHeight, "events_count", len(tx.Response.Events))

		for i, event := range tx.Response.Events {
			m.logger.Debug("ALL EVENTS: Event found", "index", i, "type", event.Type, "attrs_count", len(event.Attrs))

			// Log all event attributes
			for j, attr := range event.Attrs {
				m.logger.Debug("ALL EVENTS: Event attribute", "event_type", event.Type, "attr_index", j, "key", attr.Key, "value", attr.Value)
			}
		}
	}
}
