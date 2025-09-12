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
	LDType      string
	Description string
}

func (e entry) Title() string {
	if e.Name != "" {
		return "[" + e.Name + "](#" + e.LDType + ")"
	}
	return e.LDType
}

func Row(i interface{}) entry {
	ld := i.(LogoGraph).JsonLD()
	return entry{
		Name:        ld.StringVal("name"),
		LDType:      ld.StringVal("@type"),
		Description: ld.StringVal("description"),
	}
}

func Render(_ string) string {
	key := "description"
	rows := []entry{
		Row(Pflow),
		Row(AibLabs),
		Row(AllInBits),
		Row(Photon),
		Row(Atone),
		Row(Event),
	}

	result := cb + "\n"
	// Header
	result += "| Name | Type | " + key + " |\n"
	result += "| ---- | ---- | ------- |\n"
	// Rows
	for _, r := range rows {
		result += "| " + r.Name + " | " + r.LDType + " | " + r.Description + " |\n"
	}
	return result
}
