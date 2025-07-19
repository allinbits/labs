package user

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

// Link takes a base64 encoded ed25519 signed claim from the gno discord linker bot.
// If the claim is valid, it will use the claim to link a gno address to a discord id.
// A gno address may only be linked to a single discord ID and a single discord ID may
// only be linked to a single gno address.
func Link(cur realm, encodedClaim string) {
	claim, err := validateEncodedClaim(encodedClaim, false)
	if err != nil {
		panic(err)
	}
	if err := ds.set(claim); err != nil {
		panic(err)
	}

	// Emit UserLinked event
	std.Emit("UserLinked",
		"address", claim.addr.String(),
		"discordID", claim.discordID,
	)
}

// UnlinkByCaller removes a discord link, based on the caller address
// This does not require a claim because the caller is the link owner
func UnlinkByCaller(cur realm) {
	caller := std.PreviousRealm().Address()

	// Get the discord ID before removing
	claim := ds.getByAddress(caller)
	if claim != nil {
		// Emit UserUnlinked event
		std.Emit("UserUnlinked",
			"address", caller.String(),
			"discordID", claim.discordID,
		)
	}

	ds.removeByAddress(caller)
}

// UnlinkByClaim takes an encodedClaim from a valid discord bot
// and unlinks a discordID from a gno address. This is useful if you
// still have access to your discord account, but you have lost
// access to your old gno address.
func UnlinkByClaim(cur realm, encodedClaim string) {
	claim, err := validateEncodedClaim(encodedClaim, false)
	if err != nil {
		panic(err)
	}

	// Get the existing claim to retrieve the address
	existingClaim := ds.getByDiscordID(claim.discordID)
	if existingClaim != nil {
		// Emit UserUnlinked event
		std.Emit("UserUnlinked",
			"address", existingClaim.addr.String(),
			"discordID", claim.discordID,
		)
	}

	ds.removeByDiscordID(claim.discordID)
}

// GetLinkedAddress takes a discord ID and returns a linked gno address
func GetLinkedAddress(discordID string) std.Address {
	claim := ds.getByDiscordID(discordID)
	if claim == nil {
		return std.Address("")
	}
	return claim.addr
}

// GetLinkedDiscordID takes an address and returns a linked discord ID
func GetLinkedDiscordID(address std.Address) string {
	claim := ds.getByAddress(address)
	if claim == nil {
		return ""
	}
	return claim.discordID
}
