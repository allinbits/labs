package patch

import (
	"gno.land/r/buidlthefuture000/events/gnolandlaunch"
)

const releaseNotes = `
example patch 01
`

var api = &gnolandlaunch.Api{}

func init() {
	api.SetPatchLevel(1) // set the patch level to 1
}

func Render(_ string) string {
	return releaseNotes
}
