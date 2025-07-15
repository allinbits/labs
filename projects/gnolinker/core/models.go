package core

import "time"

// UserIdentity represents a platform-agnostic user identity linked to a Gno address
type UserIdentity struct {
	PlatformID   string
	PlatformType string
	GnoAddress   string
	LinkedAt     time.Time
}

// RoleMapping represents a mapping between a Gno realm role and a platform role
type RoleMapping struct {
	RealmPath     string
	RealmRoleName string
	PlatformRole  PlatformRole
	LinkedAt      time.Time
	LinkedBy      string // Platform ID of the organizer who linked it
}

// PlatformRole is an abstraction for platform-specific roles
type PlatformRole struct {
	ID   string
	Name string
}

// RoleStatus represents the sync status of a role for a user
type RoleStatus struct {
	RoleMapping RoleMapping
	IsMember    bool
	SyncedAt    time.Time
}

// Claim represents a signed claim for linking
type Claim struct {
	Type      ClaimType
	Data      string
	Signature string
	CreatedAt time.Time
}

type ClaimType string

const (
	ClaimTypeUserLink ClaimType = "user_link"
	ClaimTypeRoleLink ClaimType = "role_link"
)