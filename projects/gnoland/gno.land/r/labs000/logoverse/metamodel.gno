package logoverse

import (
	"net/url"

	eve "gno.land/p/eve000/event/component"
)

type metamodelObj struct{}

var Metamodel metamodelObj

func (metamodelObj) Cid() string {
	return Metamodel.JsonLD().Cid()
}

var _ LogoGraph = metamodelObj{}

func (metamodelObj) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":    []string{"https://schema.org", "https://petri.net/schema"},
		"@type":       "ImageObject",
		"name":        "Metamodel",
		"description": "Metamodel is a gno package for drawing and testing “flow” diagrams of how things move through a system—like orders through a shop, tasks through a team, or patients through a clinic.",
		"hasPart": []interface{}{
			eve.JsonLDMap{
				"@type":       "SoftwareApplication",
				"name":        "Petri Net Metamodel",
				"description": "A framework for modeling and simulating Petri nets.",
				"url":         "https://gno.land/p/labs/metamodel",
			},
		},
		"author": eve.JsonLDMap{
			"@type": "Organization",
			"name":  "Gno.land",
			"url":   "https://gno.land",
		},
	}
}

func (metamodelObj) SVG() string {
	return `<svg id="` + Metamodel.Cid() + `" xmlns="http://www.w3.org/2000/svg" width="150" height="150" viewBox="0 0 150 150" role="img" fill="black">
<title>Metamodel Petri Net Glyph</title>
<circle cx="40" cy="75" r="18" stroke="black" stroke-width="3" fill="#f0f0f0"/>
<rect x="90" y="60" width="30" height="30" stroke="black" stroke-width="3" fill="#fff"/>
<line x1="60" y1="75" x2="90" y2="75" stroke="black" stroke-width="2" marker-end="url(#arrow)"/>
<defs>
  <marker id="arrow" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="black"/>
  </marker>
</defs>
</svg>`

}

func (metamodelObj) DataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(Metamodel.SVG())
}

func (metamodelObj) Image(url ...string) string {
	if len(url) == 0 {
		return "![metamodelObj](" + Metamodel.DataUrl() + ")"
	}
	return "[![metamodelObj](" + Metamodel.DataUrl() + ")](" + url[0] + ")"
}

func (metamodelObj) Thumbnail() string {
	return Metamodel.Image()
}

// TODO: make this an open/composable object
