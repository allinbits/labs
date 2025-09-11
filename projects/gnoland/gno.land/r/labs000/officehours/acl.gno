package officehours

import (
	"std"
)

var (
	admin           string
)

func init() {
	admin = std.PreviousRealm().Address().String()
}

func assertAccess() {
    callerAddr := std.PreviousRealm().Address().String()
    if callerAddr == admin {
        return
    }
    panic("access denied: caller "+ callerAddr + " is not admin " + admin )
}
