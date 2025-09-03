package logoverse

import (
	"strings"
	"gno.land/p/demo/ufmt"
)

func init() {
	if registry != nil {
		registry["$logoglyph"] = Term{Word: "logoglyph", Binding: logoglyphDef}
	}
}

func logoglyphDef(path string) string {
	names := parseListFromPathLogoglyph(path)
	svg := buildLogoglyphSVG(names)
	return "## $logoglyph\n\n![$logoglyph](" + dataURL(svg) + ")\n"
}

func parseListFromPathLogoglyph(_ string) []string {
	return []string{"$Minecraft"}
}


func buildLogoglyphSVG(names []string) string {
	var label, base string
	if hex, clean, ok := extractInlineColorLabel(names[0]); ok {
		label, base = clean, hex
	} else {
		label, base = names[0], pickRing(0)
	}

	border := lightenHex(base, -0.35)
	steel := "#c7ccd3"
	steelD := "#9aa3ad"
	wood := "#8a5a3c"
	text := "#243"

	W, H := 320.0, 320.0
	cx, cy := W/2, H/2

	var sb strings.Builder
	sb.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	sb.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g">`, W, H, W, H))
	sb.WriteString(`<title>$logoglyph — large pickaxe and shovel crossed</title>`)

	// Background circle
	sb.WriteString(ufmt.Sprintf(
		`<circle cx="%g" cy="%g" r="%g" fill="%s" stroke="%s" stroke-width="8"/>`,
		cx, cy, 120.0, base, border,
	))

	// Crossed tool helper
	drawTool := func(deg float64, head func()) {
		sb.WriteString(ufmt.Sprintf(`<g transform="translate(%g,%g) rotate(%g)">`, cx, cy, deg))
		sb.WriteString(`<rect x="-5" y="-60" width="10" height="120" rx="3" fill="` + wood + `" stroke="#5f3e26" stroke-width="1.5"/>`)
		head()
		sb.WriteString(`</g>`)
	}

	// --- Larger Pickaxe Head ---
	drawTool(-35.0, func() {
		sb.WriteString(`
			<path d="M -60 -75
			         Q -15 -95 0 -60
			         Q 15 -95 60 -75"
				fill="` + steel + `" stroke="` + steelD + `" stroke-width="1.5"/>`)
	})

	// --- Wide Shovel ---
	drawTool(35.0, func() {
		sb.WriteString(`
			<path d="M -18 -80
			         Q 0 -100 18 -80
			         L 18 -58 Q 0 -44 -18 -58 Z"
				fill="` + steel + `" stroke="` + steelD + `" stroke-width="1.5"/>`)
	})

	// Optional label
	if label != "" {
		sb.WriteString(ufmt.Sprintf(
			`<text x="%g" y="%g" text-anchor="middle" font-size="16" font-weight="600" fill="%s">%s</text>`,
			cx, H-20, text, esc(label),
		))
	}

	sb.WriteString(`</svg>`)
	return sb.String()
}
