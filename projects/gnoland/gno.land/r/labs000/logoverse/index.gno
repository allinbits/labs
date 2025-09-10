package logoverse

var cb = `
#### Welcome to a "**small 'L' logoverse**"
This is an index of immutable objects found in this realm.
`

func Render(_ string) string {
	return cb + " \n## Pflow.xyz \n" + Pflow.Image() +
		"\n\n---\n\n" +
		"## AllInBits.com \n" + AllInBits.Image()
}
