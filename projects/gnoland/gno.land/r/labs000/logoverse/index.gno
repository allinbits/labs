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
}

var rows = []entry{
    Row(Pflow),
    Row(AibLabs),
    Row(AllInBits),
    Row(Photon),
    Row(Atone),
    Row(Event),
}

var columns = []string{"name", "description"}

func Row(i interface{}) entry {
	ld := i.(LogoGraph).JsonLD()
	return entry {
		Name:        ld.StringVal(columns[0]),
		Description: ld.StringVal(columns[1]),
	}
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
		result += "| " + r.Name + " | " + r.Description + " |\n"
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