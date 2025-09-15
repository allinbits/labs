package logoverse

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

var cb = `
## Welcome to the **logoverse**.
` + AibLabs.Image() + `
**Software as a Universe**.\
Every object has a CID (base) and a sealed CID (projection).\
Links aren’t static—they compute new objects.\
Immutable, composable, attributed by default.

Stop writing services. Start minting universes.`

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

type Projectable interface {
	ToPath(...interface{}) string
	FromPath(path string) interface{}
	Compose(...interface{}) eve.JsonLDMap
}

type LogoGraph interface {
	SVG() string
	JsonLD() eve.JsonLDMap
	Cid() string
	Thumbnail() string
}

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
	proj, isProj := r.Object.(Projectable)
	if !isProj {
		panic("object is not projectable")
	}
	r.Object = proj.FromPath(path)
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
	ldg, ok := i.(LogoGraph)
	if !ok {
		panic("object must implement LogoGraph interface")
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
	Register(Event),
	Register(Metamodel),
	Register(OfficeHours),
	Register(PepeSilvia),
	Register(Pflow),
	Register(Photon),
	Register(Wojak),
}

var columns = []string{"cid", "name", "description", "committer"}

func (e Record) String() string {
	return "| [" + e.Cid[len(e.Cid)-8:] + "](?cid=" + e.Cid + ") | " + e.Name + " | " + e.Description + " | [" + e.Committer[len(e.Committer)-8:] + "](/u/" + e.Committer + ") |\n"
}

func Render(path string) string {
	q := eve.ParseQuery(path)
	cid, hasCid := q["cid"]
	if !hasCid {
		if len(q["v"]) == 1 && q["v"][0] == "seq" {
			return counter.String() // FIXME: remove dup below...
		}
		return renderTable()
	}

	v, found := registry.Get(cid[0])
	if !found {
		return "cid not found" // TODO: incorporate form here
	}

	r := v.(Record)
	proj, isProj := r.Object.(Projectable)
	if isProj {
		r.Object = proj.FromPath(path)
	}

	if format, ok := q["v"]; ok {
		switch format[0] {
		case "ldpath":
			if ldpath, ok := q["ldpath"]; ok && len(ldpath) > 0 {
				ld := r.Object.(LogoGraph).JsonLD()
				parts := strings.Split(ldpath[0], ".")
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
				return r.Object.(LogoGraph).JsonLD().String()
			}
			return ""
		case "cid":
			if isProj {
				return "[" + proj.Compose(r.Object).Cid() + "](?cid=" + proj.Compose(r.Object).Cid() + ")"
			} else {
				return "[" + r.Cid + "](?cid=" + r.Cid + ")"
			}
		case "sequence":
			return "FIXME"
			//return r.Seq.String()
		case "committer":
			return r.Committer
		case "svg":
			return r.Object.(LogoGraph).SVG()
		case "thumbnail":
			return r.Object.(LogoGraph).Thumbnail()
		case "json":
			if isProj {
				return proj.Compose(r.Object).String()
			}
			return r.Object.(LogoGraph).JsonLD().String()
		}
	}

	if seal, ok := q["seal"]; ok && isProj {
		if !isCIDv1(seal[0]) {
			return "invalid seal: not a CIDv1"
		}
		cid := proj.Compose(r.Object).Cid()
		if seal[0] != cid {
			return "invalid seal: expected " + cid + " but got " + seal[0]
		}
	}

	return renderObject(r.Object)
}

func renderObject(obj interface{}) string {
	glyph := obj.(LogoGraph)
	ld := glyph.JsonLD()
	var sb strings.Builder
	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString(glyph.Thumbnail() + "\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")
	sb.WriteString("#### CID\n")
	cid := ld.Cid()
	if proj, ok := obj.(Projectable); ok {
		if _, found := registry.Get(cid); !found {
			sb.WriteString(cid + "\n\n")
			sb.WriteString(eve.Button("Commit Projection:    "+cid[len(cid)-8:], proj.ToPath(obj)+"&submit=register"+"\n"))
		} else {
			sb.WriteString("[" + cid + "](" + proj.ToPath(obj) + ")\n")
		}
	} else {
		sb.WriteString("[" + cid + "](?cid=" + cid + ")\n")
	}
	sb.WriteString("\n#### JSON-LD\n")
	sb.WriteString("```json\n" + strings.TrimSpace(ld.String()) + "\n```\n")
	return sb.String()
}

func renderTable() string {
	var sb strings.Builder
	sb.WriteString(cb + "\n")
	// Header
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
