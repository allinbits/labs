package user

import (
	"std"

	"gno.land/p/demo/mux"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/txlink"
)

var (
	router = mux.NewRouter()
)

func init() {
	router.HandleFunc("", renderHome)
	router.HandleFunc("link/d/{id}", renderLinkByDiscordID)
	router.HandleFunc("link/g/{addr}", renderLinkByGnoAddr)
	router.HandleFunc("claim/{encodedClaim}", renderClaim)
}

// TODO: make an endpoint with smart link
// that can accept a URL encoded base64

func Render(path string) string {
	return router.Render(path)
}

func renderHome(w *mux.ResponseWriter, r *mux.Request) {
	w.Write("# DiscordLinker Home\n\n")
	w.Write("Welcome. This realm is used to link your Discord ID to your gno address.\n\n")

	w.Write("You can link your Discord ID to your gno address by adding `:link/d/{id}` to this URL. or\n\n")
	w.Write("You can link your gno address to your Discord ID by using adding `:link/g/{addr}` to this URL.\n\n")

	w.Write("To get started, go to the discord bot on the gno.land discord server and type `/gnolinker help` for additional information.\n")
}

func renderLinkByDiscordID(w *mux.ResponseWriter, r *mux.Request) {
	discordID := r.GetVar("id")
	w.Write("# Linked Account by Discord ID\n\n")
	gnoAddr := GetLinkedAddress(discordID)

	if string(gnoAddr) == "" {
		w.Write("Sorry, We couldn't find Link for that Discord ID.")
		return
	}
	w.Write("```\ngno Address:  " + string(gnoAddr) + "\n\n")
	w.Write("Discord ID:   " + discordID + "\n```")

}

func renderLinkByGnoAddr(w *mux.ResponseWriter, r *mux.Request) {
	gnoAddr := r.GetVar("addr")
	w.Write("# Linked Account by gno Address\n\n")
	discordID := GetLinkedDiscordID(std.Address(gnoAddr))

	if discordID == "" {
		w.Write("Sorry, We couldn't find Link for that gno Address.")
		return
	}
	w.Write("```\ngno Address:  " + string(gnoAddr) + "\n\n")
	w.Write("Discord ID:   " + discordID + "\n```")
}

func renderClaim(w *mux.ResponseWriter, r *mux.Request) {
	encodedClaim := r.GetVar("encodedClaim")

	// Check if this is an unlink operation
	isUnlink := r.Query.Get("unlink") == "true"

	w.Write("# User Claim Manager\n")
	if isUnlink {
		w.Write("View your Claim details from the discord linker bot. Sign the transaction with the magic link to unlink these identities.\n")
	} else {
		w.Write("View your Claim details from the discord linker bot. Sign the transaction with the magic link to link these identities.\n")
	}

	claim, err := validateEncodedClaim(encodedClaim, true)
	if err != nil {
		w.Write("\nIt appears your claim is invalid.\n\n")
		w.Write(string(err.Error()))
		return
	}

	if isUnlink {
		w.Write(ufmt.Sprintf(`
## Easy Action:

[Unlink Accounts](%v)

## What you are unlinking

This will unlink your Discord ID from your Gno address, removing the connection between these identities.

### discordID

%v

### Gno Address

%v

`, txlink.NewLink("UnlinkByClaim").AddArgs("encodedClaim", encodedClaim).URL(),
			claim.discordID,
			string(claim.addr)))
	} else {
		w.Write(ufmt.Sprintf(`
## Easy Action:

[Claim Linked Accounts](%v)

## What you are linking

This will link your Discord ID to your Gno address, allowing you to use your Discord ID to interact with Gno applications.

### discordID

%v

### Gno Address

%v

`, txlink.NewLink("Link").AddArgs("encodedClaim", encodedClaim).URL(),
			claim.discordID,
			string(claim.addr)))
	}

	if !isUnlink {
		w.Write(ufmt.Sprintf(`
## Other Actions:

- [Remove Linked Account by Gno Address](%v) - Use this to unlink from your discord ID only using your gno address.
- [Remove Link by Claim](%v) - Use this to unlink from your discord ID, even if you've lost access to your old gno address.
- [Confirm link](/r/linker000/discord/user/v0:link/g/%v)

`,

			txlink.NewLink("Unlink").AddArgs("encodedClaim", encodedClaim).URL(),
			txlink.NewLink("UnlinkByClaim").AddArgs("encodedClaim", encodedClaim).URL(),
			string(claim.addr),
		))
	}

	w.Write(ufmt.Sprintf(`
## Raw Encoded Claim

%v

## Payload

### discordID

%v

### Gno Address

%v

`, encodedClaim, claim.discordID, string(claim.addr)))
}
