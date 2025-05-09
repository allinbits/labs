package user

import (
	"errors"
	"std"

	"gno.land/p/demo/avl"
)

type datastore struct {
	byAddr      *avl.Tree
	byDiscordID *avl.Tree
}

func (ds *datastore) set(claim *Claim) error {
	if ds.getByAddress(claim.addr) != nil {
		return errors.New("datastore: gno address is already linked")
	}
	if ds.getByDiscordID(claim.discordID) != nil {
		return errors.New("datastore: discord id is already linked")
	}
	ds.byAddr.Set(string(claim.addr), claim)
	ds.byDiscordID.Set(claim.discordID, claim)
	return nil
}

func (ds *datastore) removeByAddress(addr std.Address) {
	value, removed := ds.byAddr.Remove(string(addr))
	if removed {
		claim := value.(*Claim)
		ds.byDiscordID.Remove(claim.discordID)
	}
}

func (ds *datastore) removeByDiscordID(id string) {
	value, removed := ds.byDiscordID.Remove(id)
	if removed {
		claim := value.(*Claim)
		ds.byAddr.Remove(string(claim.addr))
	}
}

func (ds datastore) getByAddress(addr std.Address) *Claim {
	value, ok := ds.byAddr.Get(string(addr))
	if !ok {
		return nil
	}
	return value.(*Claim)
}

func (ds datastore) getByDiscordID(id string) *Claim {
	value, ok := ds.byDiscordID.Get(id)
	if !ok {
		return nil
	}
	return value.(*Claim)
}
