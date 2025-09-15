package officehours

import (
	"std"

	"gno.land/p/demo/avl"
)

var registry = Registry{Tree: avl.NewTree()}

// Register adds the given episodes to the registry.
func Register(episodes map[string]Record) {
	registry.Register(episodes)
}

// UpVote registers an upvote for the given episode by the given cid.
func UpVote(_ realm, episode string, cid string) {
	registry.AssertExists(episode)
	std.Emit("UpVote", "cid", cid, "episode", episode)
}

// DownVote registers a downvote for the given episode by the given cid.
func DownVote(_ realm, episode string, cid string) {
	registry.AssertExists(episode)
	std.Emit("DownVote", "cid", cid, "episode", episode)
}

// Propose adds a new proposal link to the list of recent proposals.
func Propose(_ realm, episode string, cid string, path string) {
	registry.AssertExists(episode)
	path = Normalize(path)
	proposal.Add(cid, path)
	std.Emit("Propose", "episode", cid, "path", path)
}

// ListProposals returns a newline-separated list of recent proposal links.
func ListProposals(_ realm) string {
	return proposal.List()
}
