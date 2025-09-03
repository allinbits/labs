package logoverse

import (
	"strings"
	"net/url"
	"gno.land/p/demo/ufmt"
)

// objects.gno
// A pure-SVG page that renders a voxel-looking row of "$objects" as isometric blocks.
// Works identically on gno.land (no <foreignObject>, no JS).

type block struct {
	i, j, k int    // grid coordinates (i right, j back, k up)
	mat    string // material key: stone | dirt | grass
	label  string // optional text label drawn under the block
}

type colors struct{ Top, Left, Right string }

func init() {
	// register "$objects" as a routable term if the registry/Term exist in this package
	if registry != nil {
		registry["$objects"] = Term{Word: "objects", Binding: objectsDef}
	}
}

// objectsDef returns markdown with an embedded data: SVG
func objectsDef(path string) string {
	names := parseListFromPath(path) // default set if not provided
	svg := buildObjectsSVG(names)
	return "## $objects\n\n![$objects](" + dataURL(svg) + ")\n\n" + renderLegend(names)
}

// REVIEW: consider query on registry
func parseListFromPath(path string) []string {
	return []string{"$stone", "$dirt", "$grass", "$sand", "$water", "$lava", "$wood", "$ice", "$gold"}
}

func renderLegend(names []string) string {
	if len(names) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("### Objects\n\n")
	for _, n := range names {
		b.WriteString("- ")
		b.WriteString(n)
		b.WriteString("\n")
	}
	return b.String()
}

func dataURL(svg string) string {
	return "data:image/svg+xml;utf8," + url.PathEscape(svg)
}

// buildObjectsSVG emits a row of isometric voxel blocks (pure <polygon> SVG).
func buildObjectsSVG(names []string) string {
	// Map each object name to a material; cycle stone->dirt->grass
	mats := []string{"stone", "dirt", "grass", "sand", "water", "lava", "wood", "ice", "gold"}

	// Make blocks array
	blocks := make([]block, 0, len(names))
	for i, name := range names {
		blocks = append(blocks, block{i: i, j: 0, k: 0, mat: mats[i%len(mats)], label: name})
	}

	// Rendering parameters
	W := 80.0  // top diamond width
	H := 40.0  // top diamond height
	Z := 36.0  // block side height

	// ViewBox
	viewW, viewH := 480.0, 400.0

	// Center the row horizontally
	n := float64(len(blocks))
	originX := viewW/2 - (n-1)*(W/4) // because cx = originX + i*(W/2)
	originY := 120.0                 // vertical baseline

	palette := map[string]colors{
        "stone":   {Top: "#aeb6c1", Left: "#919cac", Right: "#737c88"},
        "dirt":    {Top: "#946c45", Left: "#7a5638", Right: "#64462d"},
        "grass":   {Top: "#2cb673", Left: "#23a368", Right: "#1e8a58"},
        "sand":    {Top: "#f7e9b0", Left: "#e6d28a", Right: "#cbb76b"},
        "water":   {Top: "#4fc3f7", Left: "#039be5", Right: "#0277bd"},
        "lava":    {Top: "#ff7043", Left: "#d84315", Right: "#bf360c"},
        "wood":    {Top: "#a0522d", Left: "#8b4513", Right: "#654321"},
        "ice":     {Top: "#b3e5fc", Left: "#81d4fa", Right: "#4fc3f7"},
        "gold":    {Top: "#ffd700", Left: "#e6be8a", Right: "#bfa14a"},
	}

	var sb strings.Builder
	// Header
	sb.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
    sb.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g" role="img">`, viewW, viewH, viewW, viewH))
	sb.WriteString(`  <title>$objects — voxel isometric row</title>`)
	sb.WriteString(`  <defs>`)
	sb.WriteString(`    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">`)
	sb.WriteString(`      <stop offset="0%" stop-color="#bfe6ff"/>`)
	sb.WriteString(`      <stop offset="100%" stop-color="#eef8ff"/>`)
	sb.WriteString(`    </linearGradient>`)
	sb.WriteString(`  </defs>`)
	sb.WriteString(`  <rect width="100%" height="100%" fill="url(#sky)"/>`)

	// helpers
	mk := func(pts [][2]float64) string {
		var b strings.Builder
		for idx, p := range pts {
			if idx > 0 {
				b.WriteByte(' ')
			}
			b.WriteString(ufmt.Sprintf("%g,%g", p[0], p[1]))
		}
		return b.String()
	}
	project := func(i, j, k int) (cx, cy float64) {
		cx = originX + (float64(i)-float64(j))*(W/2)
		cy = originY + (float64(i)+float64(j))*(H/2) - float64(k)*Z
		return
	}

	// draw blocks
	for _, bl := range blocks {
		c := palette[bl.mat]
		cx, cy := project(bl.i, bl.j, bl.k)
		// top diamond corners
		top := [2]float64{cx, cy - H/2}
		right := [2]float64{cx + W/2, cy}
		bottom := [2]float64{cx, cy + H/2}
		left := [2]float64{cx - W/2, cy}
		// extrusions
		leftDown := [2]float64{left[0], left[1] + Z}
		rightDown := [2]float64{right[0], right[1] + Z}
		bottomDown := [2]float64{bottom[0], bottom[1] + Z}
		// faces
		sb.WriteString(ufmt.Sprintf(`  <polygon points="%s" fill="%s"/>`, mk([][2]float64{left, bottom, bottomDown, leftDown}), c.Left))
		sb.WriteString(ufmt.Sprintf(`  <polygon points="%s" fill="%s"/>`, mk([][2]float64{right, bottom, bottomDown, rightDown}), c.Right))
		sb.WriteString(ufmt.Sprintf(`  <polygon points="%s" fill="%s"/>`, mk([][2]float64{top, right, bottom, left}), c.Top))
		// label
		if bl.label != "" {
			textY := bottomDown[1] + 16
			sb.WriteString(ufmt.Sprintf(`  <text x="%g" y="%g" text-anchor="middle" font-size="12" fill="#334">%s</text>`, cx, textY, esc(bl.label)))
		}
	}

	sb.WriteString(`</svg>`)
	return sb.String()
}

// escape minimal XML special chars in labels
func esc(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	return s
}
