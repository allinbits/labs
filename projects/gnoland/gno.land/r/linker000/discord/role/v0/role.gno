package role

var (

	// ds is the primary datastore for claims
	ds *datastore
)

func init() {
	ds = newDatastore()
}

// Link takes an encoded claim and saves it to the datastore, or it panics and rolls back the transaction
func Link(encodedClaim string) {
	crossing()
	claim, err := validateEncodedClaim(encodedClaim, false)
	if err != nil {
		panic(err)
	}

	if err := ds.set(claim); err != nil {
		panic(err)
	}
}

// UnlinkByClaim takes a base64 encoded string of a ed25519 signed claim, if if it passes
// validation, it removes the linked role from registry.
func UnlinkByClaim(encodedClaim string) {
	crossing()
	claim, err := validateEncodedClaim(encodedClaim, false)
	if err != nil {
		panic(err)
	}
	ds.removeByPathRoleGuild(claim.realmPath, claim.roleName, claim.discordGuildID)
}

// GetLinkedDiscordRole takes a realmPath, roleName, and discordGuildID and returns a LinkedRealmRole
// If no link exists, it returns an empty LinkedRealmRole. The combination of realm path + realm role
// + discord server gives a globally unique namespace to associate with a discord role id
func GetLinkedDiscordRole(realmPath, roleName, discordGuildID string) LinkedRealmRole {
	crossing()
	claim := ds.getByPathRoleGuild(realmPath, roleName, discordGuildID)
	if claim == nil {
		return LinkedRealmRole{}
	}
	return claim.RealmRoleDetails()
}

// GetLinkedDiscordRoleJSON returns a json encoded string for GetLinkedDiscordRole
func GetLinkedDiscordRoleJSON(realmPath, roleName, discordGuildID string) string {
	crossing()
	lrr := GetLinkedDiscordRole(realmPath, roleName, discordGuildID)
	return lrr.ToJSON()
}

// GetLinkedRealmRole takes a discordGuildID and discordRoleID and returns a LinkedRealmRole.
// The combination of discord server + role id gives a globally unique way to identify this link.
func GetLinkedRealmRole(discordGuildID, discordRoleID string) LinkedRealmRole {
	crossing()
	claim := ds.getByGuildRole(discordGuildID, discordRoleID)
	if claim == nil {
		return LinkedRealmRole{}
	}
	return claim.RealmRoleDetails()
}

// GetLinkedRealmRoleJSON provides a json encoded string for GetLinkedRealmRole
func GetLinkedRealmRoleJSON(discordGuildID, discordRoleID string) string {
	crossing()
	lrr := GetLinkedRealmRole(discordGuildID, discordRoleID)
	return lrr.ToJSON()
}

// ListLinkedRoles takes a realmPath and discord guildID and returns a list of
// all LinkedRealmRoles with based on role names.
func ListLinkedRoles(realmPath, guildID string) []LinkedRealmRole {
	crossing()
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
	crossing()
	return linkedRealmRolesToJSON(ListLinkedRoles(realmPath, guildID))
}
