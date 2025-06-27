package events

import(
    "std"
    "strings"
)

var (
	realmAllowPrefix []string
)

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/") // must be in realm sub-path
}

func hasAllowedPrefix() bool {
	prevRealm := std.PreviousRealm().PkgPath()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(prevRealm, callerPath) {
			return true
		}
	}
	return prevRealm == ""
}

func assertAccess() {
	if !hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}