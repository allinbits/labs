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
	LDType:      "Glyph",
	Description: "Gno Links Yield Projectable Hypermedia",
}

var _ eve.LogoGraph = Glyph
var _ eve.Projectable = Glyph
var _ eve.PageTemplate = Glyph

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

	if url := q.Get("url"); url != "" {
		o.Url = url
	} else {
		o.Url = "?glyph=Glyph"
	}

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

	q["url"] = append(q["url"], obj.Url)
	return eve.BuildQuery(q)
}

func (g glyphObj) Compose(obj interface{}) eve.LogoGraph {
	switch v := obj.(type) {
	case string:
		obj := glyphObj{Url: v}
		obj.ParentCids = append(obj.ParentCids, g.Cid())
		return obj
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

func (glyphObj) Header() string {
    return "\n---\n"
}

func (g glyphObj) Body(path string) string {
    return Glyph.Introduction() + "\n" + Glyph.Diagram()
}

func (glyphObj) Footer() string {
    return "\n---\n"
}

func (glyphObj) Diagram() string {
return "```" + `
(source URL) ──► [Browser] ──► [GnoWeb: Render(path)]
                             │
                             ▼
                        (ABCI query)
                             │
                             ▼
                      [Blockchain state]
                             │
                   projection/JSON-LD/SVG
                             │
                             ▼
                         [Browser] ──► (User edits)
                             │                 │
                             │                 ▼
                             └────────── sign tx ◄── [User/Signer]
                                               │
                                               ▼
                                       [Blockchain commit]
                                               │
                                         emits events
                                               │
                                               ▼
                              (new CID / state) ──► [GnoWeb]
                                               │
                                               ▼
                                            [Browser]
` + "```"
}


func (glyphObj) Introduction() string {
return `
## What are Glyphs?

A **Glyph** is a small, portable piece of information in the Logoverse.
Think of it like a digital card that carries a name, description, and a unique ID (CID).
Each Glyph can point to other Glyphs (its “parents”), forming a chain of ideas and history.

## How to Use

- **View**: Open a Glyph in your browser to see its details, images, or JSON data.
- **Link**: Copy the Glyph’s URL and share it—others will see the same canonical view.
- **Edit or Extend**: You can make changes or create a new Glyph based on an existing one.
- **Commit**: When you save, the blockchain locks in the new Glyph with its own unique ID.

Glyphs are designed to be **simple, durable, and easy to share**, so anyone can build on them without worrying about things disappearing or changing behind the scenes.

## Projections

Glyphs can be projected into different formats, like SVG images or JSON-LD data, making them versatile for various applications.

If a Glyph implements the [**eve.PageTemplate**](/p/eve000/event/component$source&file=logograph.gno) interface, it can also render a full web page with a header, body, and footer.


`
}