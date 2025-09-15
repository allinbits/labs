package logoverse

import (
    eve "gno.land/p/eve000/event/component"
)

type logoVerse struct{}

var LogoVerse = logoVerse{}
var _ LogoGraph = LogoVerse

func (logoVerse) Cid() string {
    return LogoVerse.Compose().Cid()
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
    return LogoVerse.Compose()
}

func (logoVerse) ThumbnailSvg(width, height string) string {
    return AibLabs.ThumbnailSvg(width, height)
}

func (logoVerse) Compose() eve.JsonLDMap {

    return eve.JsonLDMap{
        "@context":   "https://schema.org",
        "type":       "CreativeWork",
        "name":       "Logoverse",
        "description": LogoVerse.Description(),
        "url":        "/r/labs000/logoverse",
        "image":      LogoVerse.Image(),
        "thumbnail":  LogoVerse.Thumbnail(),
        "author": map[string]any{
            "type": "Organization",
            "name": "AllInBits",
            "url":  "https://allinbits.com",
        },
        "keywords": []string{
            "logoverse",
            "aiblabs",
            "immutable",
            "composable",
            "cid",
            "projection",
            "gno.land",
            "software as a universe",
        },
        "license":      "https://github.com/gnolang/gno/blob/master/LICENSE.md",
    }
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