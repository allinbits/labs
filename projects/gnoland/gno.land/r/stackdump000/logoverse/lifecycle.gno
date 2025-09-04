package logoverse

import (
	"strings"
	"gno.land/p/demo/ufmt"
)

// Registers: $lifecycle
func init() {
	if registry != nil {
		registry["$lifecycle"] = Term{Word: "testloop", Binding: testLoopDef}
	}
}

// testLoopDef returns markdown with an embedded data: SVG plus a legend.
func testLoopDef(path string) string {
	names := []string{
		"$hypothesize", "$predict", "$probe", "$compare", "$update", "$retire_or_refine",
	}
	svg := buildTestLoopSVG()
	return "## $lifecycle — compact model testing loop\n\n![$lifecycle](" + dataURL(svg) + ")\n\n" + renderLoopLegend(names)
}

// renderLoopLegend lists the loop stages using your style.
func renderLoopLegend(names []string) string {
	if len(names) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("### Stages\n\n")
	for _, n := range names {
		b.WriteString("- ")
		b.WriteString(n)
		b.WriteString("\n")
	}
	b.WriteString("\n**Flow:** $hypothesize → $predict → $probe → $compare → $update → $retire_or_refine\n")
	return b.String()
}

// buildTestLoopSVG draws a clean circular loop with arrowed edges (pure <svg>).
func buildTestLoopSVG() string {
	viewW, viewH := 720.0, 440.0

	// Layout
	cx, cy := viewW/2, viewH/2
	radius := 140.0

	// Node positions (clockwise, starting at top)
	type node struct {
		id, label string
		x, y      float64
		fill      string
	}
	nodes := []node{
		{"Hypothesize", "$hypothesize", cx, cy - radius, "#b3e5fc"},           // top
		{"Predict", "$predict", cx + 0.866*radius, cy - 0.5*radius, "#dcedc8"}, // 2 o'clock
		{"Probe", "$probe", cx + 0.866*radius, cy + 0.5*radius, "#fff9c4"},     // 4 o'clock
		{"Compare", "$compare", cx, cy + radius, "#ffe0b2"},                    // bottom
		{"Update", "$update", cx - 0.866*radius, cy + 0.5*radius, "#f8bbd0"},   // 8 o'clock
		{"Refine", "$retire_or_refine", cx - 0.866*radius, cy - 0.5*radius, "#c5cae9"}, // 10 o'clock
	}

	// Build SVG
	var sb strings.Builder
	sb.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	sb.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g" role="img">`, viewW, viewH, viewW, viewH))
	sb.WriteString(`<title>$lifecycle — hypothesis → predict → probe → compare → update → retire/refine</title>`)

	// Defs: arrow marker + soft background
	sb.WriteString(`
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#eef7ff"/>
      <stop offset="100%" stop-color="#ffffff"/>
    </linearGradient>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M0 0 L10 5 L0 10 Z" fill="#345"/>
    </marker>
  </defs>
  <rect width="100%" height="100%" fill="url(#sky)"/>
`)

	// Helper to line → path
	//line := func(x1, y1, x2, y2 float64) string {
	//	return ufmt.Sprintf(`M %g %g L %g %g`, x1, y1, x2, y2)
	//}

	// Edges (clockwise loop)
	edge := func(a, b node) {
		// Slight radial outward offset for aesthetics
		dx, dy := b.x-a.x, b.y-a.y
		mx, my := (a.x+b.x)/2, (a.y+b.y)/2
		// Perpendicular nudge (reverse sign to flip curve direction)
		nx, ny := dy, -dx
		// Normalize nudge
		l := 1.0
		if dx*dx+dy*dy > 0 {
			l = 1.0 / (float64Pow(dx*dx+dy*dy, 0.5))
		}
		nx *= 12 * l
		ny *= 12 * l

		// Shorten the end of the edge so the arrowhead is not hidden by the node
		arrowPad := 50.0
		edgeLen := float64Pow(dx*dx+dy*dy, 0.5)
		tx := b.x - dx/edgeLen*arrowPad
		ty := b.y - dy/edgeLen*arrowPad

		d := ufmt.Sprintf(`M %g %g Q %g %g %g %g`, a.x, a.y, mx+nx, my+ny, tx, ty)
		sb.WriteString(ufmt.Sprintf(`<path d="%s" fill="none" stroke="#345" stroke-width="2.5" marker-end="url(#arrow)"/>`, d))
	}

	// Draw edges around the ring
	for i := 0; i < len(nodes); i++ {
		edge(nodes[i], nodes[(i+1)%len(nodes)])
	}

	// Title
	sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" text-anchor="middle" font-size="18" fill="#234" font-weight="600">$lifecycle — falsifiable model workflow</text>`, cx, 26.0))

	// Draw nodes
	for _, n := range nodes {
		sb.WriteString(ufmt.Sprintf(`<circle cx="%g" cy="%g" r="44" fill="%s" stroke="#345" stroke-width="2"/>`, n.x, n.y, n.fill))
		sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" text-anchor="middle" font-size="12" fill="#223" font-weight="700">%s</text>`, n.x, n.y-6, esc(n.id)))
		sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" text-anchor="middle" font-size="11" fill="#334">%s</text>`, n.x, n.y+14, esc(n.label)))
	}

	// Side notes: error + credence
	sb.WriteString(ufmt.Sprintf(`
  <g transform="translate(-210,310)">
    <rect x="%g" y="%g" width="200" height="88" rx="10" ry="10" fill="#f4f6f8" stroke="#c5ced6"/>
    <text x="%g" y="%g" font-size="13" fill="#223" font-weight="700">Operational semantics</text>
    <text x="%g" y="%g" font-size="11" fill="#334">• $compare emits $error (distance)</text>
    <text x="%g" y="%g" font-size="11" fill="#334">• $update adjusts $credence / routing</text>
    <text x="%g" y="%g" font-size="11" fill="#334">• $retire_or_refine when budget ≤ 0</text>
  </g>
`, cx-140, cy-190, cx-128, cy-170, cx-128, cy-152, cx-128, cy-136, cx-128, cy-120))

	sb.WriteString(`</svg>`)
	return sb.String()
}

// Minimal pow since math is trimmed in Gno contexts sometimes.
func float64Pow(x, y float64) float64 {
	// Very rough: y either 0.5 used above; sqrt via Newton's method.
	if y == 0.5 {
		if x <= 0 {
			return 0
		}
		z := x
		for i := 0; i < 8; i++ {
			z = 0.5 * (z + x/z)
		}
		return z
	}
	// Fallback (not used here)
	return x
}
