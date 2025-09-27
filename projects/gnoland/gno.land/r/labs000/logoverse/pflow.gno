package logoverse

import (
	"net/url"

	eve "gno.land/p/eve000/event/component"
)

/*
	By treating data as code, this glyph becomes a first-class entity in gno.land.

It can be stored, versioned, and composed directly, without extra boilerplate or access control.
If it carried internal state, we’d need many more methods to mutate it —
but as pure code/data, it remains lightweight, composable, and self-describing.
*/
type pflowEditor struct{}

var Pflow pflowEditor

func (pflowEditor) Cid() string {
	return Pflow.JsonLD().Cid()
}

var _ eve.LogoGraph = pflowEditor{}

func (pflowEditor) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context":    []string{"https://schema.org", "https://pflow.xyz/schema"},
		"@type":       "ImageObject",
		"name":        "pflow.xyz",
		"description": "Petri-net models for web3 - Provides a state machine [json+ld schema](https://pflow.xyz/schema).",
		"hasPart": []interface{}{
			eve.JsonLDMap{
				"@type":       "Product",
				"name":        "Pflow Editor",
				"description": "A single page app for building and sharing petri-net models.",
				"url":         "https://pflow.xyz",
			},
		},
		"author": eve.JsonLDMap{
			"@type": "Person",
			"name":  "Matt York",
			"url":   "https://github.com/stackdump",
		},
	}
}

func (pflowEditor) SVG() string {
	return `<svg id="` + Pflow.Cid() + `" xmlns="http://www.w3.org/2000/svg" width="150" height="33" viewBox="0 0 150 33" role="img" fill="black" >
<g fill="#000" transform="scale(0.3,0.3)"><path d="M100.88 28.02H78.46v5.61h-5.6v5.6h-5.6v-5.6h5.6v-5.61h5.6V5.6h-5.6V0H61.65v5.6h-5.6v28.02h-5.6V5.6h-5.6V0H33.64v5.6h-5.6v22.42h5.6v5.61h5.6v5.6h-5.6v-5.6h-5.6v-5.61H5.6v5.61H0v11.21h5.6v5.6h28.02v5.6H5.6v5.61H0v11.21h5.6v5.6h22.42v-5.6h5.6v-5.61h5.6v5.61h-5.6v5.6h-5.6v22.42h5.6v5.6h11.21v-5.6h5.6V72.86h5.6v28.02h5.6v5.6h11.21v-5.6h5.6V78.46h-5.6v-5.6h-5.6v-5.61h5.6v5.61h5.6v5.6h22.42v-5.6h5.6V61.65h-5.6v-5.61H72.84v-5.6h28.02v-5.6h5.6V33.63h-5.6v-5.61zM67.25 56.04v5.61h-5.6v5.6H44.84v-5.6h-5.6V44.84h5.6v-5.6h16.81v5.6h5.6v11.21zM157.14 28.02h-11.21v11.21h11.21zM190.77 39.23h11.21V28.02h-33.63v11.21z"></path><path d="M179.56 72.86h-11.21V39.23h-11.21v56.05h-11.21v11.21h33.63V95.28h-11.21V84.07h33.63V72.86zM201.98 50.44v22.42h11.21V39.23h-11.21zM235.61 28.02H224.4v11.21h11.21v33.63H224.4v11.21h33.63V72.86h-11.21V39.23h11.21V28.02h-11.21V16.81h-11.21z"></path><path d="M246.82 5.6v11.21h22.42V5.6zM302.87 61.65V5.6h-22.42v11.21h11.21v56.05h-11.21v11.21h33.63V72.86h-11.21zM336.5 50.44V39.23h-11.21v33.63h11.21zM358.92 50.44h-11.21v11.21h11.21zM358.92 39.23h11.21V28.02H336.5v11.21zM347.71 72.86H336.5v11.21h33.63V72.86zM370.13 50.44v22.42h11.21V39.23h-11.21zM414.97 39.23V28.02h-22.42v11.21h11.21v22.42h11.21zM426.18 61.65h-11.21v11.21h11.21zM437.39 72.86h-11.21v11.21h11.21zM448.6 50.44V28.02h-11.21v44.84h11.21zM459.81 72.86H448.6v11.21h11.21zM471.02 61.65h-11.21v11.21h11.21zM482.23 28.02h-11.21v33.63h11.21V39.23h11.21V28.02z"></path>
</g></svg>`
}

func (pflowEditor) DataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(Pflow.SVG())
}

func (pflowEditor) Image(url ...string) string {
	if len(url) == 0 {
		return "![pflowEditor](" + Pflow.DataUrl() + ")"
	}
	return "[![pflowEditor](" + Pflow.DataUrl() + ")](" + url[0] + ")"
}

func (pflowEditor) Thumbnail() string {
	return Pflow.Image()
}

func (pflowEditor) Content(urlPath ...string) *eve.Content {
	url := "https://pflow.dev"
	if len(urlPath) > 0 {
		url = urlPath[0]
	}
	return &eve.Content{
		Published: true, Markdown: Pflow.Image(url),
	}
}

func (pflowEditor) Render() string {
	return Pflow.Content().Render()
}

func (pflowEditor) Author() *eve.Speaker {
	return &eve.Speaker{
		Name:        "Matt York",
		Address:     "g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz",
		Affiliation: "[allinbits.com](https://allinbits.com)",
		Biography:   "[gh/stackdump](https://github.com/stackdump)\n\n" + Pflow.Render(),
	}
}
