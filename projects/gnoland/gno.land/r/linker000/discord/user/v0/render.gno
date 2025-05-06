package user

import (
	"std"

	"gno.land/p/demo/mux"
)

var (
	router = mux.NewRouter()
)

func init() {
	router.HandleFunc("", renderHome)
	router.HandleFunc("link/d/{id}", renderLinkByDiscordID)
	router.HandleFunc("link/g/{addr}", renderLinkByGnoAddr)
}

func Render(path string) string {
	return router.Render(path)
}

func renderHome(w *mux.ResponseWriter, r *mux.Request) {
	w.Write("# DiscordLinker Home\n\n")
	w.Write("Welcome. This smart contract is used to link your Discord ID to your gno address.\n\n")
	w.Write("To get started, go to the discord bot on the gno.land discord server and type `!help` for additional information.\n")
	w.Write("Once you've linked your accounts, you can search for the link by your gno address by going [here](http://localhost:8888/r/linker/discord/user:link/g/g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t).\n")
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
