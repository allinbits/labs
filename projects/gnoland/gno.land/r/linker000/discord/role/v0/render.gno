package role

import (
	// "std"
	"gno.land/p/demo/mux"
)

var (
	router = mux.NewRouter()
)

func init() {
	router.HandleFunc("", renderHome)
	router.HandleFunc("link/d/{discordGuidID}/{discordRoleID}", renderGetLinkedRealmRole)
	router.HandleFunc("link/r/{discordGuidID}", renderListLinkedRoles)
}

func Render(path string) string {
	return router.Render(path)
}

func renderHome(w *mux.ResponseWriter, r *mux.Request) {
	w.Write("# Discord Role Realm Linker \n\n")
	w.Write("Welcome. This realm is used for registering linked roles between Discord and a Realm.\n\n")
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
