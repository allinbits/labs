package logoverse

import (
	eve "gno.land/p/eve000/event/component"
)

type logoVerse struct{}

var LogoverseContext = eve.JsonLDMap{
	"@version":  1.1,
	"logoverse": "/r/labs000/logoverse#",

	// Term definitions
	"Glyph":    "logoverse:Glyph",
	"parents": map[string]any{
	    "@id":  "logoverse:parents",
        "@type": "@id",
        "@container": "@set",
	},
	"commit": map[string]any{
	    "@id": "logoverse:commit",
        "@type": "@id",
	},
}

var LogoVerse = logoVerse{}
var _ eve.LogoGraph = LogoVerse

func (logoVerse) Cid() string {
	return LogoVerse.JsonLD().Cid()
}

func (logoVerse) renderOpts() map[string]any {
	return map[string]any{
		"dev":      map[string]any{},
		"labsnet1": map[string]any{},
	}
}

func (logoVerse) Image() string {
	return AibLabs.Image()
}

func (logoVerse) DataUrl() string {
	return AibLabs.DataUrl()
}

func (logoVerse) Thumbnail() string {
	return AibLabs.Thumbnail()
}

func (logoVerse) SVG() string {
	return AibLabs.SVG()
}

func (logoVerse) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":    []any{"https://schema.org", LogoverseContext},
        "@type":       "CreativeWork",
		"@id":         "{{CID}}", // filled in by projection
		"name":        "Logoverse",
		"description": LogoVerse.Description(),
		"url":         "/r/labs000/logoverse",
		"banner":       "/r/labs000/logoverse?glyph=Logoverse&embed=img",
		"thumbnail":      "/r/labs000/logoverse?glyph=Logoverse&embed=thumbnail",
		"author": map[string]any{
			"@type": "Organization",
			"name": "AllInBits",
			"url":  "https://allinbits.com",
		},
		"license": "https://github.com/gnolang/gno/blob/master/LICENSE.md",
		"hasPart": map[string]any{
            "@type": "WebPage",
            "name":  "Glyph",
            "url":   "/r/labs000/logoverse?glyph=Glyph",
            "about": "Glyph is the fundamental building block of the Logoverse.",
        },
	}
}

func (logoVerse) ThumbnailSvg(width, height string) string {
	return AibLabs.ThumbnailSvg(width, height)
}

func (logoVerse) Description() string {
	return `Software as a Universe.`
}

func (logoVerse) Introduction() string {

	desc := `The [**logoverse**](/r/labs000/logoverse) is a universe of immutable, composable objects with CIDs.

Links aren’t static—they compute new objects.\
Software as a Universe.\
Every object has a CID (base) and a sealed CID (projection).\
Immutable, composable, attributed by default.

Stop writing services. Start minting universes.`

	return desc
}
