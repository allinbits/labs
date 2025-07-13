package gnocap

import (
	"strings"
)

var width = 750
var height = 750

var gridSize = 250

var description = "grid size 250x250"

var JsonLd = `{
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "Gno.land Stack Dump Example",
    "description": "` + description + `",
    "url": "https://gnoserve.fly.dev/r/stackdump000/gnocap"
}`

var jsonLd = "\n\n```jsonld\n\n" + JsonLd + "\n\n```"

var intro = `# GnoCap:  ` + description

var body = `
## single grid 25*25 segment
- [A0z](./gnocap:A0z): zoom in on a single 25x25 segment
- [gnocap:svg](./gnocap:svg): View all 100 tiles at once

![el](/svg/r/stackdump000/gnocap:A0z:svg)
`

var controls = `
`

func getFormat(input string) string {
	if strings.HasSuffix(input, ":svg") {
		return "svg"
	}
	return "md"
}
