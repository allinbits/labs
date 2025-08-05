package role

import (
	"std"
)

var (

	// ds is the primary datastore for claims
	ds *datastore
)

func init() {
	ds = newDatastore()
}

// Link takes individual claim parameters and saves the role link to the datastore
func Link(cur realm, blockHeight int64, discordAccountID, discordGuildID, discordRoleID string,
	address std.Address, roleName, realmPath, signature string) {
	claim, err := validateLinkClaim(blockHeight, discordAccountID, discordGuildID, discordRoleID,
		address, roleName, realmPath, signature, false)
	if err != nil {
		panic(err)
	}

	if err := ds.set(claim); err != nil {
		panic(err)
	}

	// Mark signature as used
	ds.markSignatureUsed(signature, blockHeight)

	// Emit RoleLinked event
	std.Emit("RoleLinked",
		"realmPath", claim.realmPath,
		"roleName", claim.roleName,
		"discordGuildID", claim.discordGuildID,
		"discordRoleID", claim.discordRoleID,
	)
}

// UnlinkByClaim takes individual claim parameters and removes the linked role from registry
func UnlinkByClaim(cur realm, blockHeight int64, discordAccountID, discordGuildID string,
	realmPath, roleName, signature string) {
	claim, err := validateUnlinkClaim(blockHeight, discordAccountID, discordGuildID,
		realmPath, roleName, signature)
	if err != nil {
		panic(err)
	}

	// Get the existing claim to retrieve the discord role ID
	existingClaim := ds.getByPathRoleGuild(claim.realmPath, claim.roleName, claim.discordGuildID)
	if existingClaim != nil {
		// Emit RoleUnlinked event
		std.Emit("RoleUnlinked",
			"realmPath", claim.realmPath,
			"roleName", claim.roleName,
			"discordGuildID", claim.discordGuildID,
			"discordRoleID", existingClaim.discordRoleID,
		)
	}

	ds.removeByPathRoleGuild(claim.realmPath, claim.roleName, claim.discordGuildID)
	
	// Mark signature as used
	ds.markSignatureUsed(signature, blockHeight)
}

// GetLinkedDiscordRole takes a realmPath, roleName, and discordGuildID and returns a LinkedRealmRole
// If no link exists, it returns an empty LinkedRealmRole. The combination of realm path + realm role
// + discord server gives a globally unique namespace to associate with a discord role id
func GetLinkedDiscordRole(realmPath, roleName, discordGuildID string) LinkedRealmRole {
	claim := ds.getByPathRoleGuild(realmPath, roleName, discordGuildID)
	if claim == nil {
		return LinkedRealmRole{}
	}
	return claim.RealmRoleDetails()
}

// GetLinkedDiscordRoleJSON returns a json encoded string for GetLinkedDiscordRole
func GetLinkedDiscordRoleJSON(realmPath, roleName, discordGuildID string) string {
	lrr := GetLinkedDiscordRole(realmPath, roleName, discordGuildID)
	return lrr.ToJSON()
}

// GetLinkedRealmRole takes a discordGuildID and discordRoleID and returns a LinkedRealmRole.
// The combination of discord server + role id gives a globally unique way to identify this link.
func GetLinkedRealmRole(discordGuildID, discordRoleID string) LinkedRealmRole {
	claim := ds.getByGuildRole(discordGuildID, discordRoleID)
	if claim == nil {
		return LinkedRealmRole{}
	}
	return claim.RealmRoleDetails()
}

// GetLinkedRealmRoleJSON provides a json encoded string for GetLinkedRealmRole
func GetLinkedRealmRoleJSON(discordGuildID, discordRoleID string) string {
	lrr := GetLinkedRealmRole(discordGuildID, discordRoleID)
	return lrr.ToJSON()
}

// ListLinkedRoles takes a realmPath and discord guildID and returns a list of
// all LinkedRealmRoles with based on role names.
func ListLinkedRoles(realmPath, guildID string) []LinkedRealmRole {
	results := []LinkedRealmRole{}
	roles := ds.listRolesByPathGuild(realmPath, guildID)
	for _, roleName := range roles {
		claim := ds.getByPathRoleGuild(realmPath, roleName, guildID)
		results = append(results, claim.RealmRoleDetails())
	}
	return results
}

// ListLinkedRolesJSON returns a json encoded string for ListLinkedRoles.
func ListLinkedRolesJSON(realmPath, guildID string) string {
	return linkedRealmRolesToJSON(ListLinkedRoles(realmPath, guildID))
}

// ListAllRolesByGuild takes a discord guildID and returns all LinkedRealmRoles
// for that guild, regardless of realm path.
func ListAllRolesByGuild(guildID string) []LinkedRealmRole {
	results := []LinkedRealmRole{}
	claims := ds.listClaimsByGuild(guildID)
	for _, claim := range claims {
		results = append(results, claim.RealmRoleDetails())
	}
	return results
}

// ListAllRolesByGuildJSON returns a json encoded string for ListAllRolesByGuild.
func ListAllRolesByGuildJSON(guildID string) string {
	return linkedRealmRolesToJSON(ListAllRolesByGuild(guildID))
}
