package logoverse

import (
    "std"
    "strings"
    "gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

var cb = `
## Welcome to a "**small 'L' logoverse**"
`+ AibLabs.Image() + `
This is an index of immutable objects found in this realm.
`

var registry = avl.NewTree()

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
// --- register.go ---
func Register(i interface{}) string {
	ldg, ok := i.(LogoGraph)
	if !ok {
		panic("object must implement LogoGraph interface")
	}
	newCid := ldg.Cid()
	if !isLikelyCIDv1(newCid) {
		panic("object must have a likely CIDv1 (base32, 'baf...' style)")
	}

	// Nudge implementors to fill the full surface (no-ops ok).
	_ = ldg.SVG()
	_ = ldg.Thumbnail()

	ld := ldg.JsonLD()
	for _, col := range columns {
		if col == "cid" || col == "committer" { continue }
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
	std.Emit( "GlyphRegistered", "cid", rec.Cid, "ldtype", ld.StringVal("@type"))
	return newCid
}

var rows = []string{
    Register(AibLabs),
    Register(AllInBits),
    Register(Atone),
    Register(Event),
    Register(Pflow),
    Register(Photon),
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
            if format, ok := q["v"]; ok  {
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
    result := "### " + ld.StringVal("name") + "\n"
    result += glyph.Thumbnail() + "\n\n"
    result += ld.StringVal("description") + "\n\n"
    result += "#### CID\n"
    result += ld.Cid() + "\n"
    result += "#### JSON-LD\n"
    result += "```json\n" + strings.TrimSpace(ld.String()) + "\n```\n"
    return result
}

func renderTable() string {
	result := cb + "\n"
	// Header
	result += "|"
	for _, col := range columns {
		result += " " + capitalize(col) + " |"
	}
	result += "\n|"
	for range columns {
		result += " ---- |"
	}
	result += "\n"
	// Rows
	for _, cid := range rows {
	    if v, ok := registry.Get(cid); ok {
            r := v.(Record)
            result += r.String()
        }
	}
	return result
}

func capitalize(s string) string {
	if len(s) == 0 {
		return s
	}
	return string(s[0]-32) + s[1:]
}

// Lightweight CID sanity check (keeps “permissionless” ethos).
func isLikelyCIDv1(s string) bool {
	// CIDv1 is multibase (usually base32 'b...'), lowercase, no padding.
	if len(s) < 10 { return false }
	if s[0] != 'b' { return false } // multibase prefix (base32 lower)
	for _, r := range s {
		if !('a' <= r && r <= 'z' || '2' <= r && r <= '7') { // base32 alphabet
			return false
		}
	}
	// Optional beams: quick IPLD prefix sanity (not exhaustive).
	if !strings.HasPrefix(s, "baf") { return false }
	return true
}