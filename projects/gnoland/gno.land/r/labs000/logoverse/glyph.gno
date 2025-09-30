package logoverse

import (
	eve "gno.land/p/eve000/event/component"
)

type glyphObj struct {
	Url     string
	ParentCids []string
	LDType string
	Commit string
}

var Glyph = glyphObj{
	Url: "?glyph=Glyph",
}

var _ eve.LogoGraph = Glyph

func (g glyphObj) String() string {
	return g.Url
}

func (g glyphObj) IsValid() bool {
	return g.Url != ""
}

func (g glyphObj) Compose(obj interface{}) glyphObj {
	switch v := obj.(type) {
	case string:
		return glyphObj{Url: v}
	case glyphObj:
		v.ParentCids = append(v.ParentCids, g.Cid())
		if v.LDType == "" {
			v.LDType = g.LDType
		}
		return v
	default:
		return glyphObj{}
	}
}

func (g glyphObj) Cid() string {
	return g.JsonLD().Cid()
}

func (g glyphObj) SVG() string {
	return `<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
  <text x="50%" y="50%" text-anchor="middle" stroke="#000000" stroke-width="2px" dy=".3em" font-size="20">[[GLYPH]]</text>
</svg>`
}

func (g glyphObj) Thumbnail() string {
	return "[[GLYPH]]"
}

func (g glyphObj) JsonLD() eve.JsonLDMap {
	return eve.JsonLDMap{
		"@context": []any{
			"https://schema.org",
			LogoverseContext,
		},
		"@graph": []any {
			map[string]any{
			    "@id":         "{{CID}}",
				"@type":       "Glyph",
				"parents":     g.ParentCids,
				"commit":      g.Commit,
				"url":         g.Url,
			},
		},
        "name":        "Glyph",
        "description": "Gno Links Yield Projectable Hypermedia",
	}
}

// TODO: support projection where we replace name & description
// maybe need to namespace the params glyphName glyphDesc
// then we can do /r/realm/path-to-your-projection?v=1324&t=123123&h=abcd&glyphName=MyGlyph&glyphDesc=ThisIsMy

// REVIEW: use Glyph as an entry point to call other realms rendering services?
// provide methods to invoke rendering projections...
