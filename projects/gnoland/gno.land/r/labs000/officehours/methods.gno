package officehours
import (
    "std"
)

var registry = Registry{}

func Register(episodes map[string]Record) {
	registry.Register(episodes)
}

func UpVote(_ realm, episode string, cid string) {
    registry.AssertExists(episode)
    std.Emit("UpVote", "cid", cid, "episode", episode)
}

func DownVote(_ realm, episode string, cid string) {
    registry.AssertExists(episode)
    std.Emit("DownVote", "cid", cid, "episode", episode)
}

func Propose(_ realm, episode string, cid string, path string) {
    registry.AssertExists(episode)
    path = Normalize(path)
    proposal.Add(cid, path)
    std.Emit("Propose", "episode", cid, "path", path)
}

func ListProposals(_ realm) string {
    return proposal.List()
}