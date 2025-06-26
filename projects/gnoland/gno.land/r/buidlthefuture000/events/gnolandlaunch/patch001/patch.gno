package patch

import (
	"gno.land/r/buidlthefuture000/events/gnolandlaunch"
)

const releaseNotes = `
example patch 01
`

func init() {
    // TODO: update to match new permissions model
    _ = gnolandlaunch.SetPatchLevel

    // FIXME: error: cannot modify external-realm or non-realm object
	gnolandlaunch.SetPatchLevel(1) // set the patch level to 1
}

func Render(_ string) string {
	return releaseNotes
}