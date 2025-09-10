package officehours

import (
	"std"
	"strings"
)

var (
	realmAllowPrefix []string
	allowNoRealm    = true // FIXME consider disabling
)

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/") // must be in realm sub-path
}

func hasAllowedPrefix() bool {
	prevRealm := std.PreviousRealm().PkgPath()
	if prevRealm == "" && allowNoRealm {
	    return true
	}
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(prevRealm, callerPath) {
			return true
		}
	}
	return false
}

func assertAccess() {
	if !hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}
