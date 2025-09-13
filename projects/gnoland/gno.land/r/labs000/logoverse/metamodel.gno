package logoverse
import (
    "net/url"

    eve "gno.land/p/eve000/event/component"
)

type metamodelEditor struct{}

var Metamodel metamodelEditor

func (metamodelEditor) Cid() string {
	return Metamodel.JsonLD().Cid()
}

var _ LogoGraph = metamodelEditor{}

func (metamodelEditor) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":    []string{"https://schema.org", "https://petri.net/schema"},
		"@type":       "ImageObject",
		"name":        "Metamodel",
		"description": "Metamodel is a Petri net modeling framework for distributed systems.",
		"hasPart": []interface{}{
			eve.JsonLDMap{
				"@type":       "SoftwareApplication",
				"name":        "Petri Net Metamodel",
				"description": "A framework for modeling and simulating Petri nets.",
				"url":         "https://github.com/gnolang/gno/tree/master/examples/petri-net",
			},
		},
		"author": eve.JsonLDMap{
			"@type": "Organization",
			"name":  "Gno.land",
			"url":   "https://gno.land",
		},
	}
}

func (metamodelEditor) SVG() string {
	return `<svg id="` + Metamodel.Cid() + `" xmlns="http://www.w3.org/2000/svg" width="150" height="150" viewBox="0 0 150 150" role="img" fill="black">
<title>Metamodel Petri Net Glyph</title>
<circle cx="50" cy="75" r="24" stroke="black" stroke-width="3" fill="#f0f0f0"/>
<rect x="90" y="60" width="30" height="30" stroke="black" stroke-width="3" fill="#fff"/>
<line x1="74" y1="75" x2="90" y2="75" stroke="black" stroke-width="2" marker-end="url(#arrow)"/>
<defs>
  <marker id="arrow" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="black"/>
  </marker>
</defs>
</svg>`
}

func (metamodelEditor) DataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(Metamodel.SVG())
}

func (metamodelEditor) Image(url ...string) string {
	if len(url) == 0 {
		return "![metamodelEditor](" + Metamodel.DataUrl() + ")"
	}
	return "[![metamodelEditor](" + Metamodel.DataUrl() + ")](" + url[0] + ")"
}

func (metamodelEditor) Thumbnail() string {
	return Metamodel.Image()
}

func (metamodelEditor) Content(urlPath ...string) *eve.Content {
	url := "https://github.com/gnolang/gno/tree/master/examples/petri-net"
	if len(urlPath) > 0 {
		url = urlPath[0]
	}
	return &eve.Content{
		Published: true, Markdown: Metamodel.Image(url),
	}
}

func (metamodelEditor) Render() string {
	return Metamodel.Content().Render()
}

func (metamodelEditor) Author() *eve.Speaker {
	return &eve.Speaker{
		Name:        "Gno.land",
		Address:     "",
		Affiliation: "[gno.land](https://gno.land)",
		Biography:   "Metamodel is a Petri net modeling framework.\n\n" + Metamodel.Render(),
	}
}