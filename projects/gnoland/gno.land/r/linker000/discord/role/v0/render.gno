package role

import (
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
	router.HandleFunc("claim/{encodedClaim}", renderClaim)
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

func renderClaim(w *mux.ResponseWriter, r *mux.Request) {
	encodedClaim := r.GetVar("encodedClaim")

	w.Write("# Role Claim Manager\n")
	w.Write("View your Claim details from the discord linker bot. Sign the transaction with the magic link to link these roles to your server.\n")
	w.Write("You **must** sign the transaction with the magic link to link these roles to your server.\n")

	claim, err := validateEncodedClaim(encodedClaim, true)
	if err != nil {
		w.Write("\nIt appears your claim is invalid.\n\n")
		w.Write(string(err.Error()))
		return
	}

	w.Write(ufmt.Sprintf(`
## Magic Link to Link your Discord Guild Role to this Realm.

Use the link below to link your Discord role to your Realm. This will create a transaction that links the role to your Realm.

[Claim Linked Discord Role](%v)

## Other Actions:

Use this link to unlink the role from your Realm, or to confirm the link is connected to your Realm.

- [Remove Linked Discord Role](%v)
- [Confirm link](/r/linker000/discord/role/v0:link/d/%v/%v)

`,
		txlink.NewLink("Link").AddArgs("encodedClaim", encodedClaim).URL(),
		txlink.NewLink("UnlinkByClaim").AddArgs("encodedClaim", encodedClaim).URL(),
		claim.discordGuildID,
		claim.discordRoleID,
	))

	w.Write(ufmt.Sprintf(`
## Raw Encoded Claim

%v

## Payload

### Discord Guild ID

%v

### Discord Role ID

%v

### Gno Realm Path

%v

### Gno Realm Role

%v

`, encodedClaim,
		claim.discordGuildID,
		claim.discordRoleID,
		claim.realmPath,
		claim.roleName,
	))
}
