package role

import (
	"errors"

	"gno.land/p/demo/avl"
)

// datastore keeps a *Claim database indexed by key/value store optimized for 3 types of queries
// byPathRoleGuild is keyed by realmPath|roleName|guildID, if you know these 3 pieces of information
// you can quickly find the discordRoleID linked to this realm and discord server
// byGuildRole is keyed by discordGuildID|discordRoleID, if you know the discord server and role information
// this will let you find the linked gno.land realm and role combination it is linked to
// byGuildRealm is a nested AVL tree keyed by RealmPath and Guild, contains a nested AVL tree that
// keeps track of all registered roles for that realm and discord server combination, making it easier
// to perform membership lookups
type datastore struct {
	byPathRoleGuild *avl.Tree
	byGuildRole     *avl.Tree
	byPathGuild     *avl.Tree
}

func newDatastore() *datastore {
	return &datastore{
		byPathRoleGuild: avl.NewTree(),
		byGuildRole:     avl.NewTree(),
		byPathGuild:     avl.NewTree(),
	}
}

func (ds *datastore) set(claim *Claim) error {
	if claim == nil {
		return errors.New("datastore: cannot set nil claim")
	}
	if ds.getByPathRoleGuild(claim.realmPath, claim.roleName, claim.discordGuildID) != nil {
		return errors.New("datastore: the unique path-role-guild key is already linked")
	}
	if ds.getByGuildRole(claim.discordGuildID, claim.discordRoleID) != nil {
		return errors.New("datastore: the unique guild-role key is already linked")
	}
	ds.byPathRoleGuild.Set(claim.PathRoleGuildKey(), claim)
	ds.byGuildRole.Set(claim.GuildRoleKey(), claim)
	ds.addRoleToPathGuild(claim.roleName, claim.realmPath, claim.discordGuildID)
	return nil
}

func (ds *datastore) removeByPathRoleGuild(realmPath, roleName, guildID string) {
	key := fmtPathRoleGuildKey(realmPath, roleName, guildID)
	value, removed := ds.byPathRoleGuild.Remove(key)
	if removed {
		claim := value.(*Claim)
		ds.removeByGuildRole(claim.discordGuildID, claim.discordRoleID)
		ds.removeRoleFromPathGuild(claim.roleName, claim.realmPath, claim.discordGuildID)
	}
}

func (ds *datastore) removeByGuildRole(guildID, roleID string) {
	key := fmtGuildRoleKey(guildID, roleID)
	value, removed := ds.byGuildRole.Remove(key)
	if removed {
		claim := value.(*Claim)
		key := fmtPathRoleGuildKey(claim.realmPath, claim.roleName, claim.discordGuildID)
		ds.byPathRoleGuild.Remove(key)
		ds.removeRoleFromPathGuild(claim.roleName, claim.realmPath, claim.discordGuildID)
	}
}

func (ds *datastore) getByPathRoleGuild(realmPath, roleName, guildID string) *Claim {
	key := fmtPathRoleGuildKey(realmPath, roleName, guildID)
	value, ok := ds.byPathRoleGuild.Get(key)
	if !ok {
		return nil
	}
	return value.(*Claim)
}

func (ds *datastore) getByGuildRole(guildID, roleID string) *Claim {
	key := fmtGuildRoleKey(guildID, roleID)
	value, ok := ds.byGuildRole.Get(key)
	if !ok {
		return nil
	}
	return value.(*Claim)
}

func (ds *datastore) addRoleToPathGuild(roleName, realmPath, guildID string) {
	key := fmtPathGuildKey(realmPath, guildID)
	value, ok := ds.byPathGuild.Get(key)
	if !ok {
		ds.byPathGuild.Set(key, avl.NewTree())
		value, _ = ds.byPathGuild.Get(key)
	}
	roles := value.(*avl.Tree)
	roles.Set(roleName, struct{}{})
}

func (ds *datastore) removeRoleFromPathGuild(roleName, realmPath, guildID string) {
	key := fmtPathGuildKey(realmPath, guildID)
	value, ok := ds.byPathGuild.Get(key)
	if !ok {
		return
	}
	roles := value.(*avl.Tree)
	roles.Remove(roleName)
}

func (ds *datastore) listRolesByPathGuild(realmPath, guildID string) []string {
	key := fmtPathGuildKey(realmPath, guildID)
	value, ok := ds.byPathGuild.Get(key)
	if !ok {
		return []string{}
	}
	roles := value.(*avl.Tree)
	results := []string{}
	roles.Iterate("", "", func(key string, _ any) bool {
		results = append(results, key)
		return false
	})
	return results
}
