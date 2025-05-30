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
	w.Write("Welcome. This smart contract is used to link your Discord ID to your gno address.\n\n")
	w.Write("To get started, go to the discord bot on the gno.land discord server and type `!help` for additional information.\n")
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

	w.Write("# User Claim Manager\n")
	w.Write("View your Claim details from the discord linker bot. Sign the transaction with the magic link to link these identities.\n")

	claim, err := validateEncodedClaim(encodedClaim, true)
	if err != nil {
		w.Write("\nIt appears your claim is invalid.\n\n")
		w.Write(string(err.Error()))
		return
	}

	w.Write(ufmt.Sprintf(`
## Easy Actions:

- [Claim Linked Accounts](%v)
- [Remove Link by Claim](%v)
- [Confirm link](/r/linker000/discord/user/v0:link/g/%v)

`,
		txlink.NewLink("Link").AddArgs("encodedClaim", encodedClaim).URL(),
		txlink.NewLink("UnlinkByClaim").AddArgs("encodedClaim", encodedClaim).URL(),
		string(claim.addr),
	))

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
