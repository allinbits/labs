package graphql

import "fmt"

type EventAttribute struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

type GnoEvent struct {
	Type    string           `json:"type"`
	PkgPath string           `json:"pkg_path"`
	Attrs   []EventAttribute `json:"attrs"`
}

type TransactionResponse struct {
	Events []GnoEvent `json:"events"`
}

type Transaction struct {
	Hash        string              `json:"hash"`
	Index       int64               `json:"index"`
	BlockHeight int64               `json:"block_height"`
	Response    TransactionResponse `json:"response"`
	Messages    []Message           `json:"messages"`
}

type UserLinkedEventsSubscription struct {
	Transactions []Transaction `graphql:"transactions(filter: $filter)" json:"transactions"`
}

type UserUnlinkedEventsSubscription struct {
	Transactions []Transaction `graphql:"transactions(filter: $filter)" json:"transactions"`
}

// Simplified filter structure that works with the actual GraphQL schema
type SimpleEventFilter struct {
	Events SimpleEventsFilter `json:"events"`
}

type SimpleEventsFilter struct {
	Type string `json:"type"`
}

type Message struct {
	Route   string `json:"route"`
	TypeURL string `json:"typeUrl"`
	Value   MessageValue `json:"value"`
}

type MessageValue struct {
	Caller  string   `json:"caller"`
	Send    string   `json:"send"`
	PkgPath string   `json:"pkg_path"`
	Func    string   `json:"func"`
	Args    []string `json:"args"`
}

type UserLinkedEvent struct {
	Address   string
	DiscordID string
}

type UserUnlinkedEvent struct {
	Address     string
	DiscordID   string
	TriggeredBy string
}

type RoleLinkedEvent struct {
	RealmPath      string
	RoleName       string
	DiscordGuildID string
	DiscordRoleID  string
}

type RoleUnlinkedEvent struct {
	RealmPath      string
	RoleName       string
	DiscordGuildID string
	DiscordRoleID  string
}

func ParseUserLinkedEvent(event GnoEvent) (*UserLinkedEvent, error) {
	if event.Type != "UserLinked" {
		return nil, fmt.Errorf("event type %s is not UserLinked", event.Type)
	}

	result := &UserLinkedEvent{}
	for _, attr := range event.Attrs {
		switch attr.Key {
		case "address":
			result.Address = attr.Value
		case "discordID":
			result.DiscordID = attr.Value
		}
	}

	return result, nil
}

func ParseUserUnlinkedEvent(event GnoEvent) (*UserUnlinkedEvent, error) {
	if event.Type != "UserUnlinked" {
		return nil, fmt.Errorf("event type %s is not UserUnlinked", event.Type)
	}

	result := &UserUnlinkedEvent{}
	for _, attr := range event.Attrs {
		switch attr.Key {
		case "address":
			result.Address = attr.Value
		case "discordID":
			result.DiscordID = attr.Value
		case "triggeredBy":
			result.TriggeredBy = attr.Value
		}
	}

	return result, nil
}

func ParseRoleLinkedEvent(event GnoEvent) (*RoleLinkedEvent, error) {
	if event.Type != "RoleLinked" {
		return nil, fmt.Errorf("event type %s is not RoleLinked", event.Type)
	}

	result := &RoleLinkedEvent{}
	for _, attr := range event.Attrs {
		switch attr.Key {
		case "realmPath":
			result.RealmPath = attr.Value
		case "roleName":
			result.RoleName = attr.Value
		case "discordGuildID":
			result.DiscordGuildID = attr.Value
		case "discordRoleID":
			result.DiscordRoleID = attr.Value
		}
	}

	return result, nil
}

func ParseRoleUnlinkedEvent(event GnoEvent) (*RoleUnlinkedEvent, error) {
	if event.Type != "RoleUnlinked" {
		return nil, fmt.Errorf("event type %s is not RoleUnlinked", event.Type)
	}

	result := &RoleUnlinkedEvent{}
	for _, attr := range event.Attrs {
		switch attr.Key {
		case "realmPath":
			result.RealmPath = attr.Value
		case "roleName":
			result.RoleName = attr.Value
		case "discordGuildID":
			result.DiscordGuildID = attr.Value
		case "discordRoleID":
			result.DiscordRoleID = attr.Value
		}
	}

	return result, nil
}