package logoverse

import (
	"net/url"
	"std"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
	"gno.land/r/labs000/officehours"
)

var registry = avl.NewTree()

type Counter struct {
	Count int64
}

func (c *Counter) Next() string {
	c.Count++
	return c.String()
}

func (c *Counter) String() string {
	return ufmt.Sprintf("%08d", c.Count)
}

var counter = Counter{Count: 0}

type Record struct {
	Name        string
	Description string
	Cid         string
	Object      interface{}
	Committer   string
	Seq         int64
}

// EmitProjectionEvent does all validation but does not register the projected object.
func EmitProjectionEvent(base, path, seal string) (cid string) {
	return commitProjection(true, base, path, seal)
}

// CommitProjection registers a projected LogoGraph object based on a base CID and a path.
// It panics if the base CID is not found, if the object is not projectable,
// if the seal does not match the computed CID, or if the projected CID is already registered.
func CommitProjection(_ realm, base, path, seal string) (cid string) {
	return commitProjection(false, base, path, seal)
}

func commitProjection(emitOnly bool, base, path, seal string) (cid string) {
	if seal == "" {
		panic("seal parameter is required")
	}
	if !isCIDv1(base) {
		panic("invalid base: not a CIDv1")
	}
	if !isCIDv1(seal) {
		panic("invalid seal: not a CIDv1")
	}
	v, found := registry.Get(base)
	if !found {
		return "base CID not found"
	}
	r := v.(Record)
	proj, isProj := r.Object.(eve.Projectable)
	if !isProj {
		panic("object is not projectable")
	}
	r.Object = proj.FromPath(path)
	// validate jsonld
	_ = r.Object.(eve.LogoGraph).SVG()
	_ = r.Object.(eve.LogoGraph).Thumbnail()
	if !eve.IsValidJson(r.Object.(eve.LogoGraph).JsonLD().String()) {
		panic("projected object has invalid JSON-LD")
	}

	cid = proj.Compose(r.Object).Cid()
	if seal != cid {
		panic("invalid seal: expected " + seal + " but got " + cid)
	}
	if _, ok := registry.Get(cid); ok {
		panic("duplicate projected CID registered: " + cid)
	}
	rec := Record{
		Name:        r.Name + " (projected)",
		Description: r.Description + " (projected)",
		Cid:         cid,
		Object:      r.Object,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         counter.Count + 1,
	}
	std.Emit("ProjectionEvent", "cid", cid, "seal", seal, "seq", counter.Next())
	if !emitOnly {
		registry.Set(rec.Cid, rec)
	}
	return
}

// Register adds a LogoGraph object to the registry and returns its Record.
// It panics if the object does not have a valid CID or if the CID is already registered.
func Register(i interface{}) string {
	ldg, ok := i.(eve.LogoGraph)
	if !ok {
		panic("object must implement eve.LogoGraph interface")
	}
	newCid := ldg.Cid()
	if !isCIDv1(newCid) {
		panic("object must have a likely CIDv1 (base32, 'baf...' style)")
	}

	_ = ldg.SVG()
	_ = ldg.Thumbnail()

	ld := ldg.JsonLD()
	for _, col := range columns {
		if col == "cid" || col == "committer" {
			continue
		}
		if _, ok := ld[col]; !ok {
			panic("object must have " + col + " in its JSON-LD")
		}
	}
	rec := Record{
		Name:        ld.StringVal(columns[1]),
		Description: ld.StringVal(columns[2]),
		Cid:         newCid,
		Object:      i,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         counter.Count + 1,
	}
	if _, ok := registry.Get(rec.Cid); ok {
		panic("duplicate CID registered: " + rec.Cid)
	}
	registry.Set(rec.Cid, rec)
	std.Emit("Register", "cid", rec.Cid, "seq", counter.Next())
	return newCid
}

var rows = []string{
	Register(AibLabs),
	Register(AllInBits),
	Register(Atone),
	Register(Dither),
	Register(Event),
	Register(Glyph),
	Register(LogoVerse),
	Register(Metamodel),
	Register(officehours.OfficeHours{}),
	Register(PepeSilvia),
	Register(Pflow),
	Register(Photon),
	Register(Wojak),
}

var columns = []string{"cid", "name", "description", "committer"}

func (e Record) String() string {
	return "| [" + e.Cid[len(e.Cid)-8:] + "](?cid=" + e.Cid + ") | [" + e.Name + "](?glyph=" + url.QueryEscape(e.Name) + ") | " + e.Description + " | [" + e.Committer[len(e.Committer)-8:] + "](/u/" + e.Committer + ") |\n"
}

func Render(path string) string {
	q := eve.ParseQuery(path)
	cid, hasCid := q["cid"]
	if !hasCid {
		if len(q["v"]) == 1 && q["v"][0] == "seq" {
			return counter.String()
		}
		// valid names must be longer than 4 chars to be used as a filter
		if id, hasId := q["glyph"]; hasId && len(id) > 0 && len(id[0]) > 4 {
			for _, c := range rows {
				if v, ok := registry.Get(c); ok {
					r := v.(Record)
					if r.Name == id[0] {
						// REVIEW: can we consolidate this with the projection logic in commitProjection?
						proj, isProj := r.Object.(eve.Projectable)
						obj := r.Object
						if isProj {
							obj = proj.FromPath(path)
						}
						return renderObject(path, obj)
					}
				}
			}
		}
		return renderTable()
	}
	if submit, hasSubmit := q["submit"]; hasSubmit && submit[0] == "register" {
		if base, hasBase := q["base"]; hasBase && isCIDv1(base[0]) {
			if baseObj, ok := registry.Get(base[0]); ok {
				if ed, isEd := baseObj.(Record).Object.(eve.Editable); isEd {
					form := ed.RenderForm(path)
					if form != "" {
						return form
					}
				}
			} else {
				//  FIXME: it seems like wrong CID is used
				return "base cid not found: " + base[0]
			}
		} else {
			return "missing or invalid base parameter"
		}
	}

	v, found := registry.Get(cid[0])
	if !found {
		return "cid not found"
	}

	// REVIEW: can we consolidate this with the projection logic in commitProjection?
	r := v.(Record)
	proj, isProj := r.Object.(eve.Projectable)
	obj := r.Object
	if isProj {
		obj = proj.FromPath(path)
	}

	if format, ok := q["v"]; ok {
		switch format[0] {
		case "ldjson":
			if ldjson, ok := q["ldjson"]; ok && len(ldjson) > 0 {
				ld := obj.(eve.LogoGraph).JsonLD()
				parts := strings.Split(ldjson[0], ".")
				val := interface{}(ld)
				for _, p := range parts {
					if m, ok := val.(eve.JsonLDMap); ok {
						val = m[p]
					} else {
						return ""
					}
				}
				switch v := val.(type) {
				case string:
					return v
				default:
					return ufmt.Sprintf("%v", v)
				}
			} else {
				return r.Object.(eve.LogoGraph).JsonLD().String()
			}
			return ""
		case "cid":
			if isProj {
				return "[" + proj.Compose(r.Object).Cid() + "](?cid=" + proj.Compose(r.Object).Cid() + ")"
			} else {
				return "[" + r.Cid + "](?cid=" + r.Cid + ")"
			}
		case "seq":
			return ufmt.Sprintf("%d", r.Seq)
		case "committer":
			return r.Committer
		case "svg":
			return r.Object.(eve.LogoGraph).SVG()
		case "thumbnail":
			return r.Object.(eve.LogoGraph).Thumbnail()
		case "json":
			if isProj {
				return proj.Compose(r.Object).JsonLD().String()
			}
			return r.Object.(eve.LogoGraph).JsonLD().String()
		}
	}

	if seal, ok := q["seal"]; ok && isProj {
		if !isCIDv1(seal[0]) {
			return "invalid seal: not a CIDv1"
		}
		cid := proj.Compose(obj).Cid()
		if seal[0] != cid {
			return "invalid seal: expected " + cid + " but got " + seal[0]
		}
	}

	return renderObject(path, obj)
}

func renderObject(path string, obj interface{}) string {
	glyph := obj.(eve.LogoGraph)
	ld := glyph.JsonLD()
	q := eve.ParseQuery(path)
	if edit, ok := q["edit"]; ok && len(edit) > 0 && edit[0] == "true" {
		if ed, isEd := obj.(eve.Editable); isEd {
			form := ed.RenderForm(path)
			if form != "" {
				return form
			}
		}
	}
	if embed, ok := q["embed"]; ok && len(embed) > 0 && embed[0] != "" {
		switch embed[0] {
		case "svg":
			return glyph.SVG()
		case "img":
			dataUrl := "data:image/svg+xml;utf8," + url.PathEscape(glyph.SVG())
			return "![svg image](" + dataUrl + ")"
		case "thumbnail":
			return glyph.Thumbnail()
		case "name":
			return ld.StringVal("name")
		case "description":
			return ld.StringVal("description")
		case "cid":
			return ld.Cid()
		case "links":
			return ld.MarkdownLinks()
		case "jsonld", "json":
			return ld.StringWithCID()
		default:
			panic("unknown embed type: " + embed[0] + ", supported: svg, thumbnail, name, description, cid, links, jsonld")
		}
	}
	var sb strings.Builder
	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString("[" + glyph.Thumbnail() + "](" + path + "&embed=thumbnail" + ")\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")
	sb.WriteString("#### CID\n")
	cid := ld.Cid()
	if proj, ok := obj.(eve.Projectable); ok {
		if _, found := registry.Get(cid); !found {
			sb.WriteString(cid + "\n\n")
			sb.WriteString(eve.Button("Commit Projection:    "+cid[len(cid)-8:], proj.ToPath(obj)+"&base="+glyph.Cid()+"&submit=register") + "\n")
		} else {
			sb.WriteString("[" + cid + "](" + proj.ToPath(obj) + ")\n")
		}
	} else {
		sb.WriteString("[" + cid + "](?cid=" + cid + ")\n")
	}

	dataUrl := "data:image/svg+xml;utf8," + url.PathEscape(glyph.SVG())
	sb.WriteString("\n[![svg image](" + dataUrl + ")](" + path + "&embed=img" + ")\n\n")

	links := ld.MarkdownLinks()
	if links != "" {
		sb.WriteString("\n### Links\n")
		sb.WriteString(links + "\n")
	}
	sb.WriteString("\n#### JSON-LD\n")
	sb.WriteString("```json\n" + strings.TrimSpace(ld.StringWithCID()) + "\n```\n")

	sb.WriteString("\n---\n\n")
	sb.WriteString("[← index](?)\n")
	return sb.String()
}

func renderTable() string {
	var sb strings.Builder
	sb.WriteString("## Logoverse Registry\n\n")
	sb.WriteString("\n![svg image](" + LogoVerse.DataUrl() + ")\n\n")
	sb.WriteString(LogoVerse.Introduction() + "\n")

	sb.WriteString("|")
	for _, col := range columns {
		sb.WriteString(" " + capitalize(col) + " |")
	}
	sb.WriteString("\n|")
	for range columns {
		sb.WriteString(" ---- |")
	}
	sb.WriteString("\n")
	// Rows
	for _, cid := range rows {
		if v, ok := registry.Get(cid); ok {
			r := v.(Record)
			sb.WriteString(r.String())
		}
	}
	sb.WriteString("\n\n---\n\n")
	sb.WriteString("[seq:" + counter.String() + "](?v=seq)\n")
	return sb.String()
}

func capitalize(s string) string {
	if len(s) == 0 {
		return s
	}
	return string(s[0]-32) + s[1:]
}

func isCIDv1(s string) bool {
	if len(s) != 59 {
		return false
	}
	for _, r := range s {
		if !('a' <= r && r <= 'z' || '2' <= r && r <= '7') { // base32 alphabet
			return false
		}
	}
	if !strings.HasPrefix(s, "bafkrei") {
		return false
	}
	return true
}
