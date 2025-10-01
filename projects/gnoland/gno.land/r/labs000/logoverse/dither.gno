package logoverse

import (
	"net/url"

	eve "gno.land/p/eve000/event/component"
)

type ditherOrg struct{}

var Dither = ditherOrg{}

var _ eve.LogoGraph = ditherOrg{}

func (ditherOrg) Cid() string {
	return Dither.JsonLD().Cid()
}

func (ditherOrg) Image() string {
	return "![Dither](" + Dither.DataUrl() + ")"
}

func (ditherOrg) Thumbnail() string {
	return Dither.Image()
}

func (ditherOrg) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":    "https://schema.org",
		"@type":       "WebPage",
		"@id":         "{{CID}}",
		"name":        "dither.chat",
		"url":         "https://dither.chat",
		"banner":      LogoVerse.URL("?glyph=dither.chat&embed=img"),
		"thumbnail":   LogoVerse.URL("?glyph=dither.chat&embed=thumbnail"),
		"description": "Dither is a public protocol for publishing messages onchain. It is designed to be simple, durable, and open to extension by anyone.",
		"about": eve.JsonLDMap{
			"@type": "Organization",
			"name":  "allinbits.com",
		},
	}
}

// TODO: add actual dither logo when it arrives
func (ditherOrg) SVG() string {
    return AllInBits.SVG()
}

func (ditherOrg) Render() string {
	return Dither.Image()
}

func (ditherOrg) DataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(Dither.SVG())
}
