package logoverse

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

var cb = `
## Welcome to the **logoverse**.
` + AibLabs.Image() + `
This is not software as service — it’s software as universe.
`

var registry = avl.NewTree()

// Projectable is a canonical interface into the category of Links.
type Projectable interface {
    ToPath(...interface{}) string
    FromPath(path string) interface{}
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
}

// Register adds a LogoGraph object to the registry and returns its Record.
// It panics if the object does not have a valid CID or if the CID is already registered.
func Register(i interface{}) string {
	ldg, ok := i.(LogoGraph)
	if !ok {
		panic("object must implement LogoGraph interface")
	}
	newCid := ldg.Cid()
	if !isLikelyCIDv1(newCid) {
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
	}
	if _, ok := registry.Get(rec.Cid); ok {
		panic("duplicate CID registered: " + rec.Cid)
	}
	registry.Set(rec.Cid, rec)
	std.Emit("GlyphRegistered", "cid", rec.Cid, "ldtype", ld.StringVal("@type"))
	return newCid
}

var rows = []string{
	Register(AibLabs),
	Register(AllInBits),
	Register(Atone),
	Register(Event),
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
	if cid, ok := q["cid"]; ok {
		if v, ok := registry.Get(cid[0]); ok {
			r := v.(Record)
			if format, ok := q["v"]; ok {
				switch format[0] {
				case "committer":
					return r.Committer
				case "svg":
					return r.Object.(LogoGraph).Thumbnail()
				case "json":
					return r.Object.(LogoGraph).JsonLD().String()
				}
			}
			return renderObject(r.Object)
		}
		return "cid not found"
	}
	return renderTable()
}

func renderObject(obj interface{}) string {
	glyph := obj.(LogoGraph)
	ld := glyph.JsonLD()
	var sb strings.Builder
	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString(glyph.Thumbnail() + "\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")
	sb.WriteString("#### CID\n")
	sb.WriteString(ld.Cid() + "\n")
	sb.WriteString("#### JSON-LD\n")
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
	return sb.String()
}

func capitalize(s string) string {
	if len(s) == 0 {
		return s
	}
	return string(s[0]-32) + s[1:]
}

func isLikelyCIDv1(s string) bool {
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
