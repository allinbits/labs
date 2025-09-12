package logoverse

import (
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
}

// Register adds a LogoGraph object to the registry and returns its Record.
// It panics if the object does not have a valid CID or if the CID is already registered.
func Register(i interface{}) string {
    var newCid string
	if ld, ok := i.(LogoGraph); !ok {
        panic("object must implement LogoGraph interface")
    } else {
        newCid = ld.Cid()
        if len(newCid) != 59 {
            panic("object must have a valid CID")
        }
        if strings.HasPrefix(newCid, "bafkrei") == false {
            panic("object must have a valid CID")
        }
    }
    _ = i.(LogoGraph).SVG()
    _ = i.(LogoGraph).Thumbnail()
    ld := i.(LogoGraph).JsonLD()
    for _, col := range columns {
        if _, ok := ld[col]; !ok {
            if col == "cid" {
                continue
            }
            panic("object must have " + col + " in its JSON-LD")
        }
    }
    if ld.StringVal("@type") == "" {
        panic("object must have @type in its JSON-LD")
    }
	rec := Record {
		Name:        ld.StringVal(columns[1]),
		Description: ld.StringVal(columns[2]),
		Cid:         newCid,
		Object:     i,
	}
    if _, ok := registry.Get(rec.Cid); ok {
        panic("duplicate CID registered: " + rec.Cid)
    }
	registry.Set(rec.Cid, rec)
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

var columns = []string{"cid", "name", "description"}

func (e Record) String() string {
    return "| [" + e.Cid[len(e.Cid)-8:] + "](?cid=" + e.Cid + ") | " + e.Name + " | " + e.Description + " |\n"
}

func Render(path string) string {
    q := eve.ParseQuery(path)
    if cid, ok := q["cid"]; ok {
        if v, ok := registry.Get(cid[0]); ok {
            r := v.(Record)
            if format, ok := q["format"]; ok  {
                switch format[0] {
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

// capitalize returns the input string with the first letter in uppercase.
func capitalize(s string) string {
	if len(s) == 0 {
		return s
	}
	return string(s[0]-32) + s[1:]
}