package logoverse

import (
	eve "gno.land/p/eve000/event/component"
)

type logoVerse struct{}

var LogoverseContext = eve.JsonLDMap{
	"@version":  1.1,
	"logoverse": "/r/labs000/logoverse#",

	// Term definitions
	"Glyph": "logoverse:Glyph",
	"parents": map[string]any{
		"@id":        "logoverse:parents",
		"@type":      "@id",
		"@container": "@set",
	},
	"commit": map[string]any{
		"@id":   "logoverse:commit",
		"@type": "@id",
	},
}

var LogoVerse = logoVerse{}
var _ eve.LogoGraph = LogoVerse
var _ eve.PageTemplate = LogoVerse

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

func (logoVerse) URL(params ...string) string {
	url := "/r/labs000/logoverse"
	if len(params) > 0 {
		return url + params[0]
	}
	return url
}

func (logoVerse) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":    []any{"https://schema.org", LogoverseContext},
		"@type":       "CreativeWork",
		"@id":         "{{CID}}", // filled in by projection
		"name":        "Logoverse",
		"description": LogoVerse.Description(),
		"url":      LogoVerse.URL("?glyph=Logoverse&embed=page"),
		"banner":      LogoVerse.URL("?glyph=Logoverse&embed=img"),
		"thumbnail":   LogoVerse.URL("?glyph=Logoverse&embed=thumbnail"),
		"author": map[string]any{
			"@type": "Organization",
			"name":  "AllInBits",
			"url":   "https://allinbits.com",
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
	return `## What is the Logoverse?
The [**Logoverse**](/r/labs000/logoverse?glyph=Logoverse) is like a digital universe made up of tiny building blocks called **objects**.
Each object has a permanent identity (a **CID**) and can be combined with others to form bigger ideas.

- **Immutable:** once created, objects never change.
- **Composable:** you can link and combine objects to make new ones.
- **Transparent:** every object carries its own history by default.

Think of it as a library where every page is alive: when you follow a link, it doesn’t just show you something—it *creates* a new object.

This is **Software as a Universe**.
Stop writing services. **Start minting universes.**`
}

func (logoVerse) Footer() string {
    return ""
}

func (logoVerse) Header() string {
    return ""
}

func (logoVerse) Body(path string) string {
    return LogoVerse.Introduction()
}

