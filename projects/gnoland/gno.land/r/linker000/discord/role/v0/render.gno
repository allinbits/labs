package role

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
	router.HandleFunc("link/d/{discordGuidID}/{discordRoleID}", renderGetLinkedRealmRole)
	router.HandleFunc("link/r/{discordGuidID}", renderListLinkedRoles)
	router.HandleFunc("link", renderLink)
	router.HandleFunc("unlink", renderUnlink)
}

func Render(path string) string {
	return router.Render(path)
}

func renderHome(w *mux.ResponseWriter, r *mux.Request) {
	w.Write("# Discord Role Realm Linker v0\n\n")
	w.Write("Welcome. This realm is used for registering linked roles between Discord and a Realm.\n\n")

	w.Write("## byPathRoleGuild keys\n\n")
	ds.byPathRoleGuild.IterateByOffset(0, 100, func(key string, value any) bool {
		if key == "" {
			return true
		}
		w.Write(key + "\n")
		return false
	})

	w.Write("## byGuildRole keys\n\n")
	ds.byGuildRole.IterateByOffset(0, 100, func(key string, value any) bool {
		if key == "" {
			return true
		}
		w.Write(key + "\n")
		return false
	})

	w.Write("## byPathGuild keys\n\n")
	ds.byPathGuild.IterateByOffset(0, 100, func(key string, value any) bool {
		if key == "" {
			return true
		}
		w.Write(key + "\n")
		return false
	})

}

func renderGetLinkedRealmRole(w *mux.ResponseWriter, r *mux.Request) {
	discordGuidID := r.GetVar("discordGuidID")
	discordRoleID := r.GetVar("discordRoleID")

	lrr := GetLinkedRealmRole(discordGuidID, discordRoleID)

	w.Write(lrr.ToJSON())
}

func renderListLinkedRoles(w *mux.ResponseWriter, r *mux.Request) {
	discordGuidID := r.GetVar("discordGuidID")
	queryParams := r.Query
	realmPath := queryParams.Get("realm")
	if realmPath == "" {
		w.Write("No realm path in query, please use `?realm={realm_path}`")
		return
	}
	w.Write(ListLinkedRolesJSON(realmPath, discordGuidID))

}

func renderLink(w *mux.ResponseWriter, r *mux.Request) {
	// Parse query parameters
	blockHeightStr := r.Query.Get("blockHeight")
	discordAccountID := r.Query.Get("discordAccountID")
	discordGuildID := r.Query.Get("discordGuildID")
	discordRoleID := r.Query.Get("discordRoleID")
	addr := r.Query.Get("address")
	roleName := r.Query.Get("roleName")
	realmPath := r.Query.Get("realmPath")
	signature := r.Query.Get("signature")

	w.Write("# Link Discord Role to Realm\n")
	w.Write("View your claim details from the discord linker bot. Sign the transaction with the magic link to link these roles to your server.\n")

	// Validate that all required parameters are present
	if blockHeightStr == "" || discordAccountID == "" || discordGuildID == "" ||
		discordRoleID == "" || addr == "" || roleName == "" || realmPath == "" || signature == "" {
		w.Write("\nError: Missing required parameters\n")
		return
	}

	// Parse block height
	blockHeight, err := strconv.ParseInt(blockHeightStr, 10, 64)
	if err != nil {
		w.Write("\nError: Invalid block height\n")
		return
	}

	// Validate the claim
	claim, err := validateLinkClaim(blockHeight, discordAccountID, discordGuildID, discordRoleID,
		std.Address(addr), roleName, realmPath, signature, true)
	if err != nil {
		w.Write("\n## Error\n\n")
		w.Write("It appears your claim is invalid: ")
		w.Write(err.Error())
		w.Write("\n\n")

		// Still show the claim details
		w.Write(ufmt.Sprintf(`
## Claim Details (Invalid)

### Block Height
%v

### Discord Guild ID
%v

### Discord Role ID
%v

### Realm Path
%v

### Role Name
%v

### Signature
%v

`, blockHeightStr, discordGuildID, discordRoleID, realmPath, roleName, signature))

		w.Write("\n## What to do?\n\n")
		if err.Error() == "claim: signature already used" {
			w.Write("This signature has already been used. ")
			w.Write(ufmt.Sprintf("[Check existing role link](/r/linker000/discord/role/v0:link/d/%s/%s)\n\n", discordGuildID, discordRoleID))
		} else if err.Error() == "datastore: the unique path-role-guild key is already linked" {
			w.Write("This realm role is already linked in this guild.\n")
		} else if err.Error() == "datastore: the unique guild-role key is already linked" {
			w.Write(ufmt.Sprintf("This Discord role is already linked. [View existing link](/r/linker000/discord/role/v0:link/d/%s/%s)\n", discordGuildID, discordRoleID))
		} else if strings.Contains(err.Error(), "block height too old") {
			w.Write("The claim is too old. Please generate a new claim from Discord.\n")
		} else {
			w.Write("Check your parameters and try generating a new claim from Discord.\n")
		}
		return
	}

	w.Write(ufmt.Sprintf(`
## Magic Link to Link your Discord Guild Role to this Realm.

Use the link below to link your Discord role to your Realm. This will create a transaction that links the role to your Realm.

[Link Discord Role](%v)

## What you are linking

### Discord Guild ID
%v

### Discord Role ID
%v

### Realm Path
%v

### Role Name
%v

`, txlink.NewLink("Link").AddArgs("blockHeight", blockHeightStr).AddArgs("discordAccountID", discordAccountID).AddArgs("discordGuildID", discordGuildID).AddArgs("discordRoleID", discordRoleID).AddArgs("address", addr).AddArgs("roleName", roleName).AddArgs("realmPath", realmPath).AddArgs("signature", signature).URL(),
		claim.discordGuildID,
		claim.discordRoleID,
		claim.realmPath,
		claim.roleName))

	w.Write(ufmt.Sprintf(`
## Other Actions:

- [Confirm link](/r/linker000/discord/role/v0:link/d/%v/%v)

`, claim.discordGuildID, claim.discordRoleID))
}

func renderUnlink(w *mux.ResponseWriter, r *mux.Request) {
	// Parse query parameters
	blockHeightStr := r.Query.Get("blockHeight")
	discordAccountID := r.Query.Get("discordAccountID")
	discordGuildID := r.Query.Get("discordGuildID")
	realmPath := r.Query.Get("realmPath")
	roleName := r.Query.Get("roleName")
	signature := r.Query.Get("signature")

	w.Write("# Unlink Discord Role from Realm\n")
	w.Write("View your claim details from the discord linker bot. Sign the transaction with the magic link to unlink these roles from your server.\n")

	// Validate that all required parameters are present
	if blockHeightStr == "" || discordAccountID == "" || discordGuildID == "" ||
		realmPath == "" || roleName == "" || signature == "" {
		w.Write("\nError: Missing required parameters\n")
		return
	}

	// Parse block height
	blockHeight, err := strconv.ParseInt(blockHeightStr, 10, 64)
	if err != nil {
		w.Write("\nError: Invalid block height\n")
		return
	}

	// Validate the claim
	claim, err := validateUnlinkClaim(blockHeight, discordAccountID, discordGuildID,
		realmPath, roleName, signature)
	if err != nil {
		w.Write("\n## Error\n\n")
		w.Write("It appears your claim is invalid: ")
		w.Write(err.Error())
		w.Write("\n\n")

		// Still show the claim details
		w.Write(ufmt.Sprintf(`
## Claim Details (Invalid)

### Block Height
%v

### Discord Guild ID
%v

### Realm Path
%v

### Role Name
%v

### Signature
%v

`, blockHeightStr, discordGuildID, realmPath, roleName, signature))

		w.Write("\n## What to do?\n\n")
		if err.Error() == "claim: signature already used" {
			w.Write("This signature has already been used. The unlink may have already been processed.\n")
		} else if err.Error() == "claim: role mapping not found" {
			w.Write("This role mapping does not exist. There's nothing to unlink.\n")
		} else if strings.Contains(err.Error(), "block height too old") {
			w.Write("The claim is too old. Please generate a new unlink claim from Discord.\n")
		} else {
			w.Write("Try generating a new claim from Discord.\n")
		}
		return
	}

	w.Write(ufmt.Sprintf(`
## Magic Link to Unlink your Discord Guild Role from this Realm.

Use the link below to unlink your Discord role from your Realm. This will create a transaction that removes the link between the role and your Realm.

[Unlink Discord Role](%v)

## What you are unlinking

### Discord Guild ID
%v

### Discord Role ID
%v

### Realm Path
%v

### Role Name
%v

`, txlink.NewLink("UnlinkByClaim").AddArgs("blockHeight", blockHeightStr).AddArgs("discordAccountID", discordAccountID).AddArgs("discordGuildID", discordGuildID).AddArgs("realmPath", realmPath).AddArgs("roleName", roleName).AddArgs("signature", signature).URL(),
		claim.discordGuildID,
		claim.discordRoleID,
		claim.realmPath,
		claim.roleName))
}
