package logoverse

import (
	eve "gno.land/p/eve000/event/component"
)

type glyphObj struct {
	Url         string
	ParentCids  []string
	LDType      string
	Commit      string
	Name        string
	Description string
}

var Glyph = glyphObj{
	Url:         "?glyph=Glyph",
	Name:        "Glyph",
	Description: "Gno Links Yield Projectable Hypermedia",
}

var _ eve.LogoGraph = Glyph
var _ eve.Projectable = Glyph

func (g glyphObj) String() string {
	return g.Url
}

func (g glyphObj) IsValid() bool {
	return g.Url != ""
}

func (g glyphObj) FromPath(path string) interface{} {
	o := glyphObj{
		Url:         g.Url,
		LDType:      g.LDType,
		Name:        g.Name,
		Description: g.Description,
	}
	if o.LDType == "" {
		o.LDType = "Glyph"
	}

	q := eve.ParseQuery(path)
	if glyph := q.Get("glyph"); glyph != "" {
		o.Url = "?glyph=" + glyph
	}
	if name := q.Get("name"); name != "" {
		o.Name = name
	}
	if description := q.Get("description"); description != "" {
		o.Description = description
	}

	if commit := q.Get("commit"); commit != "" {
		o.Commit = commit
	}

	if len(q["parent"]) > 0 {
		for _, parent := range q["parent"] {
			o.ParentCids = append(o.ParentCids, parent)
		}
	}

	o.Url = "?glyph=Glyph" // consider getting from "redirect" in the query params + add form

	return o
}

func (g glyphObj) ToPath(o interface{}) string {
	obj := o.(glyphObj)
	q := make(map[string][]string)
	if obj.Url != "" {
		q["glyph"] = []string{obj.Url[7:]} // trim "?glyph="
	}
	if obj.Name != "" {
		q["name"] = []string{obj.Name}
	}
	if obj.Description != "" {
		q["description"] = []string{obj.Description}
	}
	if obj.Commit != "" {
		q["commit"] = []string{obj.Commit}
	}
	if len(obj.ParentCids) > 0 {
		q["parent"] = obj.ParentCids
	}
	return eve.BuildQuery(q)
}

func (g glyphObj) Compose(obj interface{}) eve.LogoGraph {
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
		"@graph": []any{
			map[string]any{
				"@id":     "{{CID}}",
				"@type":   g.LDType,
				"parents": g.ParentCids,
				"commit":  g.Commit,
				"url":     g.Url,
			},
		},
		"name":        g.Name,
		"description": g.Description,
	}
}
