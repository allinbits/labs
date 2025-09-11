package logoverse

var cb = `
#### Welcome to a "**small 'L' logoverse**"
This is an index of immutable objects found in this realm.
`

func Render(_ string) string {
	return cb + " \n## pflow.xyz \n" + Pflow.Image() +
		"\n\n---\n\n" +
		"## aiblabs.net \n" + AibLabs.Image()
}
