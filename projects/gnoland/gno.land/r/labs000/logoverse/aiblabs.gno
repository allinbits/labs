package logoverse

import (
	"net/url"

	eve "gno.land/p/eve000/event/component"
)

type aibLabs struct{}

var AibLabs = aibLabs{}

var _ eve.LogoGraph = aibLabs{}

func (aibLabs) Cid() string {
	return AibLabs.JsonLD().Cid()
}

func (aibLabs) Image() string {
	return "![AibLabs](" + AibLabs.DataUrl() + ")"
}

func (aibLabs) DataUrl() string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(AibLabs.SVG())
}

func (aibLabs) Thumbnail() string {
	return "![AibLabs](" + AibLabs.ThumbnailDataUrl() + ")"
}

func (aibLabs) ThumbnailDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(AibLabs.ThumbnailSvg("70", "30"))
}

func (aibLabs) ThumbnailSvg(w, h string) string {
	dataUrl := AibLabs.DataUrl()
	return `<svg width="` + w + `" height="` + h + `" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="none" stroke="#facade"/>
		<image href="` + dataUrl + `" width="` + w + `" height="` + h + `"/>
	</svg>`
}

func (aibLabs) SVG() string {
	return aibLogoSvg
}

func (aibLabs) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":    "https://schema.org",
		"@type":       "WebPage",
		"@id":         "{{CID}}",
		"name":        "aiblabs.net",
		"banner":      LogoVerse.URL("?glyph=Logoverse&embed=img"),
		"thumbnail":   LogoVerse.URL("?glyph=Logoverse&embed=thumbnail"),
		"description": "Working group fostering core principals: Censorship-Resistance, Sovereignty, Privacy",
		"about": eve.JsonLDMap{
			"@type": "Organization",
			"name":  "Experimental Blockchain Instances by All in Bits Labs group",
			"url":   "https://aiblabs.net",
		},
	}
}

var aibLogoSvg = `<svg id="` + AibLabs.Cid() + `" xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">
  <defs>
    <filter id="aib-drop-shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.3"/>
    </filter>
  </defs>
  <style>
    .aib-stroke { stroke: black; fill: none; }
    .aib-path { stroke-width: 4; }
    #censorship-resistance .aib-path { stroke: rgb(25, 108, 87); } /* gno.land + blockchain */
    #sovereignty .aib-path { stroke: #3498db; } /* freedom + decentralization */
    #privacy .aib-path { stroke: #27ae60; } /* privacy + security */
  </style>
  <g filter="url(#aib-drop-shadow)" transform="scale(1.5, 1.5) rotate(180, 60, 60) translate(19, 5)">
    <g id="censorship-resistance">
        <path d="M25.571,46.294 A35,35 0 0,1 69.429,73.706 M50.571,73.706 A35,35 0 0,1 94.429,46.294" class="aib-stroke aib-path"/>
    </g>
    <g id="sovereignty">
        <path d="M60,104.495 A35,35 0 0,1 60,55.505 M94.429,46.294 A35,35 0 0,1 50.571,73.706" class="aib-stroke aib-path"/>
    </g>
    <g id="privacy">
        <path d="M69.429,73.706 A35,35 0 0,1 25.571,46.294 M60,55.505 A35,35 0 0,1 60,104.495" class="aib-stroke aib-path"/>
    </g>
  </g>
</svg>
`
