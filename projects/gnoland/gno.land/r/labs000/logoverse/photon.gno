package logoverse

import (
	"net/url"

	eve "gno.land/p/eve000/event/component"
)

type photonToken struct{}

var Photon = photonToken{}

var _ eve.LogoGraph = photonToken{}

func (photonToken) Cid() string {
	return Photon.JsonLD().Cid()
}

func (photonToken) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":     "https://schema.org",
		"@type":        "FinancialProduct",
		"@id":          "{{CID}}",
		"name":         "Photon",
		"description":  "Photon is a digital asset in the AtomOne ecosystem, used as the fee currency.",
		"url":          "https://atom.one/blog/atomone-v2-the-photon-powered-upgrade/",
		"banner":       LogoVerse.URL("?glyph=$photon&embed=img"),
		"thumbnail":    LogoVerse.URL("?glyph=$photon&embed=thumbnail"),
		"tickerSymbol": "$PHOTON",
		"@graph": []any{
			eve.JsonLDMap{
				"@type":         "MonetaryAmount",
				"name":          "PHOTON",
				"currency":      "PHOTON",
				"description":   "Fee currency on AtomOne.",
				"alternateName": "$PHOTON",
				"url":           "https://atom.one/blog/atomone-v2-the-photon-powered-upgrade/",
				"sameAs": []string{
					"https://app.osmosis.zone/assets/ibc/D6E02C5AE8A37FC2E3AB1FC8AC168878ADB870549383DFFEA9FD020C234520A7",
				},
				"additionalProperty": []any{
					eve.JsonLDMap{"@type": "PropertyValue", "name": "coinMinimalDenom", "value": "uphoton"},
					eve.JsonLDMap{"@type": "PropertyValue", "name": "coinDecimals", "value": 6},
					eve.JsonLDMap{"@type": "PropertyValue", "name": "role", "value": "feeCurrency"},
				},
			},
		},
		"hasPart": []any{
			eve.JsonLDMap{
				"@type": "WebPage",
				"name":  "Photon Proposal",
				"url":   "https://gov.atom.one/proposals/5",
			},
		},
	}
}

func (photonToken) SVG() string {
	return `<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 1024 1024" fill="none">
<g clip-path="url(#photon_token)">
<path d="M1024 512C1024 794.777 794.772 1024 511.99 1024C229.208 1024 0 794.757 0 512C0 229.243 229.227 0 511.99 0C794.753 0 1024 229.223 1024 512Z" fill="#001347"/>
<path d="M226.39 558.537C246.441 675.789 336.848 768.998 452.64 793.099V793.118L455.812 829.366C317.634 805.266 209.434 693.874 190.2 554.079L226.39 558.537ZM833.79 554.061C814.537 693.855 706.396 805.247 568.179 829.348L571.352 793.1C687.143 768.999 777.549 675.77 797.581 558.538L797.601 558.519L833.79 554.061ZM462.879 223.777C342.084 244.393 246.851 339.705 226.332 460.52L226.312 460.539L190.161 465.036C209.823 321.173 323.552 207.367 467.356 187.588L462.879 223.777ZM556.614 187.549C700.4 207.328 814.147 321.153 833.81 464.997L797.64 460.501C777.121 339.706 681.886 244.375 561.092 223.759L561.111 223.739L556.614 187.549Z" fill="white"/>
<path d="M578.457 547.636L885.709 509.519L578.476 471.402L708.985 312.529L550.21 442.96L511.976 134.87L473.762 442.96L314.986 312.529L445.495 471.402L138.262 509.519L445.515 547.636L314.986 706.528L471.698 577.771L511.801 1024L552.273 577.771L708.985 706.528L578.437 547.636H578.457ZM491.185 529.511L330.093 509.538L463.269 493.01L491.808 489.467L511.995 326.662L528.64 460.714L532.202 489.467L560.742 493.01L693.917 509.519L532.825 529.492L512.015 767.052L491.204 529.492L491.185 529.511Z" fill="#01D7EB"/>
</g>
<defs>
<clipPath id="photon_token">
<rect width="1024" height="1024" fill="white"/>
</clipPath>
</defs>
</svg>`
}

func (photonToken) DataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(Photon.SVG())
}

func (photonToken) Image(urls ...string) string {
	if len(urls) == 0 {
		return "![photonToken](" + Photon.DataUrl() + ")"
	}
	return "[![photonToken](" + Photon.DataUrl() + ")](" + urls[0] + ")"
}

func (photonToken) ThumbnailDataUrl() string {
	svg := `
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 1024 1024" fill="none">
<g clip-path="url(#photon_token)">
<path d="M1024 512C1024 794.777 794.772 1024 511.99 1024C229.208 1024 0 794.757 0 512C0 229.243 229.227 0 511.99 0C794.753 0 1024 229.223 1024 512Z" fill="#001347"/>
<path d="M226.39 558.537C246.441 675.789 336.848 768.998 452.64 793.099V793.118L455.812 829.366C317.634 805.266 209.434 693.874 190.2 554.079L226.39 558.537ZM833.79 554.061C814.537 693.855 706.396 805.247 568.179 829.348L571.352 793.1C687.143 768.999 777.549 675.77 797.581 558.538L797.601 558.519L833.79 554.061ZM462.879 223.777C342.084 244.393 246.851 339.705 226.332 460.52L226.312 460.539L190.161 465.036C209.823 321.173 323.552 207.367 467.356 187.588L462.879 223.777ZM556.614 187.549C700.4 207.328 814.147 321.153 833.81 464.997L797.64 460.501C777.121 339.706 681.886 244.375 561.092 223.759L561.111 223.739L556.614 187.549Z" fill="white"/>
<path d="M578.457 547.636L885.709 509.519L578.476 471.402L708.985 312.529L550.21 442.96L511.976 134.87L473.762 442.96L314.986 312.529L445.495 471.402L138.262 509.519L445.515 547.636L314.986 706.528L471.698 577.771L511.801 1024L552.273 577.771L708.985 706.528L578.437 547.636H578.457ZM491.185 529.511L330.093 509.538L463.269 493.01L491.808 489.467L511.995 326.662L528.64 460.714L532.202 489.467L560.742 493.01L693.917 509.519L532.825 529.492L512.015 767.052L491.204 529.492L491.185 529.511Z" fill="#01D7EB"/>
</g>
<defs>
<clipPath id="photon_token">
<rect width="1024" height="1024" fill="white"/>
</clipPath>
</defs>
</svg>`
	return "data:image/svg+xml;utf8," + url.PathEscape(svg)
}

func (photonToken) Thumbnail() string {
	return "![photonToken](" + Photon.ThumbnailDataUrl() + ")"
}
