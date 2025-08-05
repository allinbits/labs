package user

import (
	"std"
	"strconv"
	"strings"

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
	router.HandleFunc("link", renderLink)
	router.HandleFunc("unlink", renderUnlink)
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

func renderLink(w *mux.ResponseWriter, r *mux.Request) {
	// Parse query parameters
	blockHeightStr := r.Query.Get("blockHeight")
	discordID := r.Query.Get("discordID")
	addr := r.Query.Get("address")
	signature := r.Query.Get("signature")

	w.Write("# Link Discord Account\n")
	w.Write("View your claim details from the discord linker bot. Sign the transaction with the magic link to link these identities.\n")

	// Validate that all required parameters are present
	if blockHeightStr == "" || discordID == "" || addr == "" || signature == "" {
		w.Write("\nError: Missing required parameters (blockHeight, discordID, address, signature)\n")
		return
	}

	// Parse block height
	blockHeight, err := strconv.ParseInt(blockHeightStr, 10, 64)
	if err != nil {
		w.Write("\nError: Invalid block height\n")
		return
	}

	// Validate the claim
	claim, err := validateLinkClaim(blockHeight, discordID, std.Address(addr), signature, true)
	if err != nil {
		w.Write("\n## Error\n\n")
		w.Write("It appears your claim is invalid: ")
		w.Write(err.Error())
		w.Write("\n\n")
		
		// Still show the claim details so user can see what they tried to claim
		w.Write(ufmt.Sprintf(`
## Claim Details (Invalid)

### Block Height

%v

### Discord ID

%v

### Gno Address

%v

### Signature

%v

`, blockHeightStr, discordID, addr, signature))
		
		w.Write("\n## What to do?\n\n")
		if err.Error() == "claim: signature already used" {
			w.Write("This signature has already been used. ")
			w.Write(ufmt.Sprintf("[Check if Discord ID %s is already linked](/r/linker000/discord/user/v0:link/d/%s)\n\n", discordID, discordID))
		} else if err.Error() == "claim: block height too old (age: 501 blocks, max: 500 blocks, claim: " + blockHeightStr + ", current: " {
			w.Write("- The claim is too old. Please generate a new claim from Discord\n")
		} else if err.Error() == "datastore: discord id is already linked" {
			w.Write(ufmt.Sprintf("- This Discord ID is already linked. [View existing link](/r/linker000/discord/user/v0:link/d/%s)\n", discordID))
		} else if err.Error() == "datastore: gno address is already linked" {
			w.Write(ufmt.Sprintf("- This Gno address is already linked. [View existing link](/r/linker000/discord/user/v0:link/g/%s)\n", addr))
		} else {
			w.Write("- Check your Discord ID and Gno address are correct\n")
			w.Write("- Try generating a new claim from Discord\n")
		}
		return
	}

	w.Write(ufmt.Sprintf(`
## Easy Action:

[Link Accounts](%v)

## What you are linking

This will link your Discord ID to your Gno address, allowing you to use your Discord ID to interact with Gno applications.

### Discord ID

%v

### Gno Address

%v

`, txlink.NewLink("Link").AddArgs("blockHeight", blockHeightStr).AddArgs("discordID", discordID).AddArgs("address", addr).AddArgs("signature", signature).URL(),
		claim.discordID,
		string(claim.addr)))

	w.Write(ufmt.Sprintf(`
## Other Actions:

- [Remove Linked Account by Gno Address](%v) - Use this to unlink from your discord ID only using your gno address.
- [Confirm link](/r/linker000/discord/user/v0:link/g/%v)

`,
		txlink.NewLink("UnlinkByCaller").URL(),
		string(claim.addr),
	))

	w.Write(ufmt.Sprintf(`
## Claim Details

### Block Height

%v

### Discord ID

%v

### Gno Address

%v

### Signature

%v

`, blockHeightStr, claim.discordID, string(claim.addr), signature))
}

func renderUnlink(w *mux.ResponseWriter, r *mux.Request) {
	// Parse query parameters
	blockHeightStr := r.Query.Get("blockHeight")
	discordID := r.Query.Get("discordID")
	signature := r.Query.Get("signature")

	w.Write("# Unlink Discord Account\n")
	w.Write("View your claim details from the discord linker bot. Sign the transaction with the magic link to unlink these identities.\n")

	// Validate that all required parameters are present
	if blockHeightStr == "" || discordID == "" || signature == "" {
		w.Write("\nError: Missing required parameters (blockHeight, discordID, signature)\n")
		return
	}

	// Parse block height
	blockHeight, err := strconv.ParseInt(blockHeightStr, 10, 64)
	if err != nil {
		w.Write("\nError: Invalid block height\n")
		return
	}

	// Validate the claim
	claim, err := validateUnlinkClaim(blockHeight, discordID, signature)
	if err != nil {
		w.Write("\n## Error\n\n")
		w.Write("It appears your claim is invalid: ")
		w.Write(err.Error())
		w.Write("\n\n")
		
		// Still show the claim details so user can see what they tried to claim
		w.Write(ufmt.Sprintf(`
## Claim Details (Invalid)

### Block Height

%v

### Discord ID

%v

### Signature

%v

`, blockHeightStr, discordID, signature))
		
		w.Write("\n## What to do?\n\n")
		if err.Error() == "claim: signature already used" {
			w.Write("This signature has already been used. The unlink may have already been processed.\n")
			w.Write(ufmt.Sprintf("[Check if Discord ID %s is still linked](/r/linker000/discord/user/v0:link/d/%s)\n\n", discordID, discordID))
		} else if err.Error() == "claim: discord ID is not linked" {
			w.Write("This Discord ID is not currently linked to any address. There's nothing to unlink.\n")
		} else if strings.Contains(err.Error(), "block height too old") {
			w.Write("- The claim is too old. Please generate a new unlink claim from Discord\n")
		} else {
			w.Write("- Try generating a new claim from Discord\n")
		}
		return
	}

	w.Write(ufmt.Sprintf(`
## Easy Action:

[Unlink Accounts](%v)

## What you are unlinking

This will unlink your Discord ID from your Gno address, removing the connection between these identities.

### Discord ID

%v

### Gno Address

%v

`, txlink.NewLink("UnlinkByClaim").AddArgs("blockHeight", blockHeightStr).AddArgs("discordID", discordID).AddArgs("signature", signature).URL(),
		claim.discordID,
		string(claim.addr)))

	w.Write(ufmt.Sprintf(`
## Claim Details

### Block Height

%v

### Discord ID

%v

### Gno Address

%v

### Signature

%v

`, blockHeightStr, claim.discordID, string(claim.addr), signature))
}
