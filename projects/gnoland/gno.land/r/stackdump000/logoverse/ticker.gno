package logoverse

import (
	"strings"
	"gno.land/p/demo/ufmt"
)

// Ticker is a short symbol that names a fungible object.
// We purposefully keep this broader than "cryptocurrency".
type Ticker struct {
	Symbol string // e.g. $ATONE, $USD, $WOOD
	Kind   string // optional: "crypto" | "fiat" | "resource" | "access" | ...
	Label  string // optional display label; falls back to Symbol
}

func init() {
	// register "$tickers" as a routable term if the registry/Term exist in this package
	if registry != nil {
		registry["$ticker"] = Term{Word: "tickers", Binding: tickersDef}
	}
}

// tickersDef returns markdown with an embedded data: SVG and a small legend.
func tickersDef(path string) string {
	// Default demo set (broader than crypto by design)
	syms := []Ticker{
		{Symbol: "$USD", Kind: "fiat"},
		{Symbol: "$ATONE", Kind: "crypto"},
		{Symbol: "$PHOTON", Kind: "crypto"},
		{Symbol: "$ALLOW", Kind: "quasi-crypto"},
		{Symbol: "$WOOD", Kind: "resource"},
		{Symbol: "$IRON", Kind: "resource"},
		{Symbol: "$TICKET", Kind: "access"},
		{Symbol: "$POINT", Kind: "loyalty"},
	}

	svg := buildTickersSVG(syms)
	legend := renderTickerLegend(syms)

	intro := "_A **Ticker** is a short term that **points to a fungible object** — not just coins. It can name any fungible supply: currencies, resources, points, permits, and more._\n\n"

	return "## $tickers\n\n![$tickers](" + dataURL(svg) + ")\n\n" + intro + legend
}

func renderTickerLegend(syms []Ticker) string {
	if len(syms) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("### Tickers\n\n")
	for _, t := range syms {
		label := t.Symbol
		if t.Label != "" {
			label = t.Label
		}
		if t.Kind != "" {
			b.WriteString("- ")
			b.WriteString(label)
			b.WriteString(" — ")
			b.WriteString(t.Kind)
			b.WriteString("\n")
		} else {
			b.WriteString("- ")
			b.WriteString(label)
			b.WriteString("\n")
		}
	}
	return b.String()
}

// buildTickersSVG draws a row of shaded "coins" with ticker labels (pure SVG, no JS).
func buildTickersSVG(syms []Ticker) string {
	viewW, viewH := 755.0, 120.0
	coinR := 36.0
	paddingX := 24.0
	step := (2*coinR + paddingX)
	startX := 40.0
	baseY := 50.0

	// Soft palette keyed by Kind (falls back to neutral)
	type pal struct{ Light, Mid, Dark string }
	palette := map[string]pal{
		"crypto":   {Light: "#b9e3ff", Mid: "#6fbef0", Dark: "#2a7fb8"},
		"quasi-crypto": {Light: "#d1b3ff", Mid: "#a366f0", Dark: "#6a17b8"},
		"fiat":     {Light: "#fff0b3", Mid: "#ffd666", Dark: "#d4a017"},
		"resource": {Light: "#e6f5d6", Mid: "#a5d86a", Dark: "#588f2a"},
		"access":     {Light: "#f5d6ff", Mid: "#d18cf0", Dark: "#8c3eb8"},
		"loyalty":  {Light: "#ffe0e0", Mid: "#ff9c9c", Dark: "#c04a4a"},
		"":         {Light: "#e0e7ef", Mid: "#b7c3d0", Dark: "#708090"},
	}

	var sb strings.Builder
	sb.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	sb.WriteString(ufmt.Sprintf(
		`<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g" role="img">`,
		viewW, viewH, viewW, viewH,
	))
	sb.WriteString(`<title>$tickers — fungible-object tickers</title>`)

	// Background
	sb.WriteString(`<defs>
  <linearGradient id="sky2" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#eef6ff"/>
    <stop offset="100%" stop-color="#fafcff"/>
  </linearGradient>
  <filter id="softShadow" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="2"/>
    <feOffset dx="0" dy="2" result="off"/>
    <feComponentTransfer>
      <feFuncA type="linear" slope="0.25"/>
    </feComponentTransfer>
    <feMerge>
      <feMergeNode in="off"/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>
</defs>`)
	sb.WriteString(`<rect width="100%" height="100%" fill="url(#sky2)"/>`)

	// Row of coins
	for i, t := range syms {
		p, ok := palette[t.Kind]
		if !ok {
			p = palette[""]
		}
		cx := startX + float64(i)*step
		cy := baseY

		// Coin body (edge + face + highlight)
		// Edge (a slightly darker ellipse behind the face to suggest thickness)
		sb.WriteString(ufmt.Sprintf(
			`<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="%s" filter="url(#softShadow)"/>`,
			cx, cy+4, coinR, coinR*0.55, p.Dark,
		))

		// Face
		sb.WriteString(ufmt.Sprintf(
			`<circle cx="%g" cy="%g" r="%g" fill="%s" stroke="%s" stroke-width="2" filter="url(#softShadow)"/>`,
			cx, cy, coinR, p.Mid, p.Dark,
		))

		// Soft highlight
		sb.WriteString(ufmt.Sprintf(
			`<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="%s" opacity="0.35"/>`,
			cx-10, cy-12, coinR*0.55, coinR*0.28, p.Light,
		))

		// Ticker text
		label := t.Symbol
		if t.Label != "" {
			label = t.Label
		}
		sb.WriteString(ufmt.Sprintf(
			`<text x="%g" y="%g" text-anchor="middle" font-size="14" font-weight="700" fill="#1e2a32">%s</text>`,
			cx, cy+5, esc(label),
		))

		// Kind caption (optional)
		if t.Kind != "" {
			sb.WriteString(ufmt.Sprintf(
				`<text x="%g" y="%g" text-anchor="middle" font-size="11" fill="#3b4b57" opacity="0.8">%s</text>`,
				cx, cy+coinR+18, esc(t.Kind),
			))
		}
	}

	sb.WriteString(`</svg>`)
	return sb.String()
}
