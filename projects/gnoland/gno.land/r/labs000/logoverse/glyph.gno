package logoverse

import (
    "strings"
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
var _ eve.Projectable = Glyph

func (g glyphObj) String() string {
	return g.Url
}

func (g glyphObj) IsValid() bool {
	return g.Url != ""
}

func (g glyphObj) FromPath(string) interface{} {
    o := glyphObj{
        Url: g.Url,
        LDType: g.LDType,
    }

    q := eve.ParseQuery(g.Url)
    if glyph := q.Get("glyph"); glyph != "" {
        o.Url = "?glyph=" + glyph
    }
    if name := q.Get("name"); name != "" {
        o.Url += "&name=" + name
    }
    if description := q.Get("description"); description != "" {
        o.Url += "&description=" + description
    }
    if parents := q["parent"]; len(parents) > 0 {
        o.ParentCids = append(o.ParentCids, parents...)
        for _, parent := range parents {
            o.Url += "&parent=" + parent
        }
    }

    return o
}

func (g glyphObj) ToPath(o interface{}) string {
	if v, ok := o.(glyphObj); ok {
		q := eve.ParseQuery(v.Url)
		glyph := q.Get("glyph")
		name := q.Get("name")
		description := q.Get("description")
		parent := q.Get("parent")
		params := []string{}
		if glyph != "" {
			params = append(params, "glyph="+glyph)
		}
		if name != "" {
			params = append(params, "name="+name)
		}
		if description != "" {
			params = append(params, "description="+description)
		}
		if parent != "" {
			params = append(params, "parent="+parent)
		}
		if len(params) > 0 {
			return "?" + strings.Join(params, "&")
		}
		return v.Url
	}
	return ""
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
