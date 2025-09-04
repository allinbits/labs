package logoverse

import (
	"strings"
	"gno.land/p/demo/ufmt"
)

type sign struct {
	label string // final label (after stripping inline color prefix)
	color string // base hex for this sign (derived or inline)
}

// Small CSS-name palette for inline convenience.
var cssName = map[string]string{
	"red": "#ff0000", "green": "#008000", "blue": "#0000ff",
	"teal": "#008080", "purple": "#800080", "navy": "#000080",
	"orange": "#ffa500", "yellow": "#ffff00", "aqua": "#00ffff",
	"lime": "#00ff00", "maroon": "#800000", "olive": "#808000",
	"silver": "#c0c0c0", "gray": "#808080", "black": "#000000",
	"white": "#ffffff",
}

// A pleasant default ring of colors if none provided inline.
var ring = []string{
	"#e57373", "#f06292", "#ba68c8", "#9575cd",
	"#7986cb", "#64b5f6", "#4fc3f7", "#4dd0e1",
	"#4db6ac", "#81c784", "#aed581", "#ffd54f",
}

func init() {
	if registry != nil {
		registry["$logograph"] = Term{Word: "logograph", Binding: logographDef}
	}
}

func logographDef(path string) string {
	names := parseListFromPathLogograph(path)
	svg := buildLogographSVG(names)
	return "## $logograph\n\n![$logograph](" + dataURL(svg) + ")\n\n" + renderLegend(names)
}

// You can wire this to your path/query later; for now a friendly default.
func parseListFromPathLogograph(path string) []string {
	return []string{"$logoglyph ←", "$logograph ↑", "$model →"}
}

// --- Inline color parsing & tiny utilities -----------------------------------

func extractInlineColorLabel(s string) (hex string, cleanLabel string, ok bool) {
	parts := strings.SplitN(s, ":", 3)
	// "#RRGGBB:Text"
	if len(parts) >= 2 && strings.HasPrefix(parts[0], "#") && len(parts[0]) >= 7 {
		return toCanonicalHex(parts[0]), parts[len(parts)-1], true
	}
	// "color:name:Text"
	if len(parts) >= 2 && strings.ToLower(parts[0]) == "color" {
		if v, has := cssName[strings.ToLower(parts[1])]; has {
			if len(parts) == 3 {
				return toCanonicalHex(v), parts[2], true
			}
			return toCanonicalHex(v), "", true
		}
	}
	return "", s, false
}

func toCanonicalHex(h string) string {
	h = strings.TrimSpace(h)
	if !strings.HasPrefix(h, "#") {
		h = "#" + h
	}
	h = strings.ToLower(h)
	if len(h) == 4 { // #rgb → #rrggbb
		h = "#" + string([]byte{h[1], h[1], h[2], h[2], h[3], h[3]})
	}
	return h
}

func pickRing(i int) string { return ring[i%len(ring)] }

func hexToRGB(h string) (int, int, int) {
	if strings.HasPrefix(h, "#") {
		h = h[1:]
	}
	if len(h) != 6 {
		return 128, 128, 128
	}
	hexv := func(c byte) int {
		switch {
		case c >= '0' && c <= '9':
			return int(c - '0')
		case c >= 'a' && c <= 'f':
			return int(c-'a') + 10
		default:
			return 0
		}
	}
	toByte := func(a, b byte) int { return (hexv(a)<<4 | hexv(b)) & 0xff }
	return toByte(h[0], h[1]), toByte(h[2], h[3]), toByte(h[4], h[5])
}

func rgbToHex(r, g, b int) string {
	clamp := func(x int) int {
		if x < 0 {
			return 0
		}
		if x > 255 {
			return 255
		}
		return x
	}
	r, g, b = clamp(r), clamp(g), clamp(b)
	hex := "0123456789abcdef"
	one := func(x int) string { return string([]byte{hex[(x>>4)&0xf], hex[x&0xf]}) }
	return "#" + one(r) + one(g) + one(b)
}

// lighten>0 toward white, lighten<0 toward black
func lightenHex(h string, factor float64) string {
	r, g, b := hexToRGB(h)
	adj := func(c int) int {
		if factor >= 0 {
			return int(float64(c) + (255.0-float64(c))*factor)
		}
		return int(float64(c) * (1.0 + factor))
	}
	return rgbToHex(adj(r), adj(g), adj(b))
}

// --- SVG builder -------------------------------------------------------------

func buildLogographSVG(names []string) string {
	// Build signs with colors
	signs := make([]sign, 0, len(names))
	for i, raw := range names {
		if hex, clean, ok := extractInlineColorLabel(raw); ok {
			signs = append(signs, sign{label: clean, color: hex})
		} else {
			signs = append(signs, sign{label: raw, color: pickRing(i)})
		}
	}

	// Canvas
	viewW, viewH := 480.0, 260.0

	// Signpost geometry
	postX := 90.0
	postTop := 40.0
	postBottom := 210.0
	postWidth := 16.0

	// Signboard layout
	signW := 260.0
	signH := 36.0
	signRadius := 6.0
	spacing := 12.0
	startY := 70.0

	// Chains/rope offsets from post
	hookOffsetX := 18.0
	signInsetX := 10.0

	var sb strings.Builder
	// Header & background
	sb.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
    sb.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g" role="img">`, viewW, viewH, viewW, viewH))
    sb.WriteString(`<title>$logograph — signpost</title>`)
	sb.WriteString(`<defs>`)
	sb.WriteString(`  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">`)
	sb.WriteString(`    <stop offset="0%" stop-color="#bfe6ff"/>`)
	sb.WriteString(`    <stop offset="100%" stop-color="#eef8ff"/>`)
	sb.WriteString(`  </linearGradient>`)
	sb.WriteString(`  <linearGradient id="wood" x1="0" y1="0" x2="0" y2="1">`)
	sb.WriteString(`    <stop offset="0%" stop-color="#9b6b3d"/>`)
	sb.WriteString(`    <stop offset="100%" stop-color="#7a4f2c"/>`)
	sb.WriteString(`  </linearGradient>`)
	sb.WriteString(`</defs>`)
	sb.WriteString(`<rect width="100%" height="100%" fill="url(#sky)"/>`)

	// Ground
	sb.WriteString(`<rect x="0" y="210" width="480" height="50" fill="#d7e8c2"/>`)
	sb.WriteString(`<ellipse cx="100" cy="210" rx="55" ry="6" fill="#b7caa3" opacity="0.6"/>`)

	// Post (vertical)
	sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="%g" height="%g" rx="3" fill="url(#wood)"/>`,
		postX, postTop, postWidth, postBottom-postTop))
	// Arm (horizontal)
	armY := startY - spacing
	armW := signW + signInsetX + 24.0
	sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="%g" height="10" rx="3" fill="url(#wood)"/>`,
		postX-2.0, armY, armW))

	// Cap
	sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="%g" height="8" rx="2" fill="#6b4526"/>`,
		postX-4.0, postTop-8.0, postWidth+8.0 ))

	// Signs
	cursorY := startY
	for _, s := range signs {
		x := postX + hookOffsetX
		y := cursorY

		// Slight 3D by darker right edge & drop shadow
		base := s.color
		stroke := lightenHex(base, -0.25)
		side := lightenHex(base, -0.15)
		top := lightenHex(base, 0.10)

		// Shadow
		sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="%g" height="%g" rx="%g" fill="#000" opacity="0.12"/>`,
			x+3, y+3, signW, signH, signRadius))

		// Main plate
		sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="%g" height="%g" rx="%g" fill="%s" stroke="%s" stroke-width="2"/>`,
			x, y, signW, signH, signRadius, top, stroke))

		// Right “thickness”
		sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="6" height="%g" rx="3" fill="%s" opacity="0.85"/>`,
			x+signW-3, y+2, signH-4, side))

		// Chains (simple)
		hookY := y - 4
		sb.WriteString(ufmt.Sprintf(`<circle cx="%g" cy="%g" r="3" fill="#666"/>`, postX+hookOffsetX-4, hookY))
		sb.WriteString(ufmt.Sprintf(`<circle cx="%g" cy="%g" r="3" fill="#666"/>`, postX+hookOffsetX+signW-16, hookY))
		sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="2" height="%g" fill="#777"/>`,
			postX+hookOffsetX-5, hookY, 6.0))
		sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="2" height="%g" fill="#777"/>`,
			postX+hookOffsetX+signW-17, hookY, 6.0))

		// Label
		if s.label != "" {
			sb.WriteString(ufmt.Sprintf(
				`<text x="%g" y="%g" text-anchor="middle" font-size="14" font-weight="600" fill="#243">%s</text>`,
				x+signW/2, y+signH/2+5, esc(s.label),
			))
		}

		cursorY += signH + spacing
	}

	sb.WriteString(`</svg>`)
	return sb.String()
}
