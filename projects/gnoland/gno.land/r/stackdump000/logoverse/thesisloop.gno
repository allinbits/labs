package logoverse

import (
	"strings"
	"gno.land/p/demo/ufmt"
)

func init() {
	if registry != nil {
		registry["$thesisloop"] = Term{Word: "thesisloop", Binding: thesisLoopDef}

		// Object terms for Dapps-as-thesis
		// registry["$thesis"]     = Term{Word: "thesis",     Binding: thesisDef}
		// registry["$assumption"] = Term{Word: "assumption", Binding: assumptionDef}
		// registry["$artifact"]   = Term{Word: "artifact",   Binding: artifactDef}   // the app/build
		// registry["$experiment"] = Term{Word: "experiment", Binding: experimentDef}
		// registry["$cohort"]     = Term{Word: "cohort",     Binding: cohortDef}
		// registry["$signal"]     = Term{Word: "signal",     Binding: signalDef}
		// registry["$metric"]     = Term{Word: "metric",     Binding: metricDef}
		// registry["$threshold"]  = Term{Word: "threshold",  Binding: thresholdDef}
		// registry["$decision"]   = Term{Word: "decision",   Binding: decisionDef}
		// registry["$runway"]     = Term{Word: "runway",     Binding: runwayDef}
	}
}

func thesisLoopDef(_ string) string {
	svg := buildThesisLoopSVG()
	names := []string{"$thesis", "$assumption", "$artifact", "$experiment", "$cohort", "$signal", "$metric", "$threshold", "$decision", "$runway"}
	return "## $thesisloop — Dapps as testable thesis\n\n![$thesisloop](" + dataURL(svg) + ")\n\n" + renderLegend(names)
}


func buildThesisLoopSVG() string {
	viewW, viewH := 760.0, 480.0
	cx, cy := viewW/2, viewH/2

	type node struct{ id, sub string; x, y float64; fill string }
	r := 150.0
	nodes := []node{
		{"Build", "$artifact", cx, cy - r, "#dcedc8"},
		{"Instrument", "$signal·$metric", cx + 0.866*r, cy - 0.5*r, "#b3e5fc"},
		{"Release", "$cohort", cx + 0.866*r, cy + 0.5*r, "#c5cae9"},
		{"Measure", "$signal→$metric", cx, cy + r, "#fff9c4"},
		{"Decide", "$threshold·$decision", cx - 0.866*r, cy + 0.5*r, "#ffe0b2"},
		{"Refine", "$thesis·$assumption", cx - 0.866*r, cy - 0.5*r, "#f8bbd0"},
	}

	var sb strings.Builder
	sb.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	sb.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g" role="img">`, viewW, viewH, viewW, viewH))
	sb.WriteString(`<title>$thesisloop — build→instrument→release→measure→decide→refine</title>
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#eef7ff"/><stop offset="100%" stop-color="#ffffff"/>
    </linearGradient>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M0 0 L10 5 L0 10 Z" fill="#345"/>
    </marker>
  </defs>
  <rect width="100%" height="100%" fill="url(#sky)"/>
`)

	// helper
	qcurve := func(x1, y1, x2, y2 float64) string {
		mx, my := (x1+x2)/2, (y1+y2)/2
		nx, ny := (y2-y1), -(x2-x1)
		// normalize nudge
		L := nx*nx + ny*ny
		if L > 0 { inv := 1.0 / sqrt(L); nx *= inv * 12; ny *= inv * 12 }
		return ufmt.Sprintf(`M %g %g Q %g %g %g %g`, x1, y1, mx+nx, my+ny, x2, y2)
	}

	// edges
	for i := 0; i < len(nodes); i++ {
		a, b := nodes[i], nodes[(i+1)%len(nodes)]
		// shorten endpoint to let arrowhead fit
		dx, dy := b.x-a.x, b.y-a.y
		L := sqrt(dx*dx + dy*dy)
		if L > 0 {
		    arrowPad := 60.0
		    b.x -= dx / L * arrowPad
		    b.y -= dy / L * arrowPad
        }
        // draw curved edge
		sb.WriteString(ufmt.Sprintf(`<path d="%s" fill="none" stroke="#345" stroke-width="2.5" marker-end="url(#arrow)"/>`, qcurve(a.x, a.y, b.x, b.y)))
	}

	// title + runway chip
	sb.WriteString(ufmt.Sprintf(`<text x="%g" y="34" text-anchor="middle" font-size="18" fill="#223" font-weight="600">$thesisloop — Dapps as testable thesis</text>`, cx))
	sb.WriteString("<g transform=\"translate(-260,330)\">") // left-align title a bit
	sb.WriteString(ufmt.Sprintf(`<rect x="%g" y="%g" width="210" height="70" rx="10" ry="10" fill="#f4f6f8" stroke="#c5ced6"/>`, cx-105, cy-180))
	sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" font-size="12" fill="#223" font-weight="700">$runway guardrail</text>`, cx-92, cy-160))
	sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" font-size="11" fill="#334">• budget/time ticks each loop</text>`, cx-92, cy-144))
	sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" font-size="11" fill="#334">• escalate if burn > value</text>`, cx-92, cy-128))
	sb.WriteString("</g>")

	// nodes
	for _, n := range nodes {
		sb.WriteString(ufmt.Sprintf(`<circle cx="%g" cy="%g" r="46" fill="%s" stroke="#345" stroke-width="2"/>`, n.x, n.y, n.fill))
		sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" text-anchor="middle" font-size="13" fill="#223" font-weight="700">%s</text>`, n.x, n.y-4, esc(n.id)))
		sb.WriteString(ufmt.Sprintf(`<text x="%g" y="%g" text-anchor="middle" font-size="11" fill="#334">%s</text>`, n.x, n.y+16, esc(n.sub)))
	}

	sb.WriteString(`</svg>`)
	return sb.String()
}

// tiny sqrt (no math import needed)
func sqrt(x float64) float64 {
	if x <= 0 { return 0 }
	z := x
	for i := 0; i < 8; i++ { z = 0.5 * (z + x/z) }
	return z
}
