package logoverse

import (
	"net/url"
)

func init() {
	if registry != nil {
		registry["$allinbits"] = Term{Word: "allinbits", Binding: func (_ string) string { return AllInBits.Markdown() } }
	}
}

type allInBits struct{}
var AllInBits = allInBits{}

func (allInBits) Markdown() string {
    return AllInBits.Image() + "\n\n" +AllInBits.Thumbnail()
}

func (allInBits) Image() string {
	return "![allinbits](" + AllInBits.DataUrl() + ")"
}

func (allInBits) DataUrl() string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(aibLogoSvg)
}

func (allInBits) Thumbnail() string {
    return "![allinbits](" + AllInBits.ThumbnailDataUrl() + ")"
}

func (allInBits) ThumbnailDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(AllInBits.ThumbnailSvg("70", "30"))
}

func (allInBits) ThumbnailSvg(w, h string) string {
	dataUrl := AllInBits.DataUrl()
	return `<svg width="` + w + `" height="` + h + `" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="none" stroke="#facade"/>
		<image href="` + dataUrl + `" width="` + w + `" height="` + h + `"/>
	</svg>`
}

func (allInBits) Svg() string {
    return aibLogoSvg
}

var aibLogoSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">
  <style>
    .aib-stroke { stroke: black; fill: none; }
    .aib-circle { stroke-width: 3; }
    .aib-path { stroke-width: 4; }
  </style>
  <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "ImageObject",
      "name": "allinbits.com",
      "description": "Censorship-Resistance, Sovereignty, Privacy",
      "author": {
        "@type": "Organization",
        "name": "All In Bits"
      }
    }
  </script>
  <g transform="scale(1.5, 1.5) rotate(180, 60, 60) translate(19, 5)">
    <circle cx="60" cy="66.7" r="3" class="aib-stroke aib-circle"/>
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