package events

import (
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
