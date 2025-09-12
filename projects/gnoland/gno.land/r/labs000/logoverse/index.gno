package logoverse

import (
	eve "gno.land/p/eve000/event/component"
)

var cb = `
#### Welcome to a "**small 'L' logoverse**"
This is an index of immutable objects found in this realm.
`

type LogoGraph interface {
	SVG() string
	JsonLD() eve.JsonLDMap
	Cid() string
}

type entry struct {
	Name        string
	Description string
	Cid         string
}

var rows = []entry{
    Row(Pflow),
    Row(AibLabs),
    Row(AllInBits),
    Row(Photon),
    Row(Atone),
    Row(Event),
}

var columns = []string{"cid", "name", "description"}

func init() {
    // build registry index by CID
}

func Row(i interface{}) entry {
	ld := i.(LogoGraph).JsonLD()
	return entry {
		Name:        ld.StringVal(columns[1]),
		Description: ld.StringVal(columns[2]),
		Cid:         ld.Cid(),
	}
}

func (e entry) String() string {
    return "| [" + e.Cid[len(e.Cid)-8:] + "](?cid=" + e.Cid + ") | " + e.Name + " | " + e.Description + " |\n"
}


func Render(path string) string {
    // TODO: build composite SVG from all logos
    return RenderTable("")
}

func RenderTable(_ string) string {

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
	for _, r := range rows {
		result += r.String()
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