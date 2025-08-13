// Package metamodel provides a framework for modeling and simulating Petri nets,
// a mathematical representation of distributed systems. It includes structures
// for places, transitions, and arcs, as well as methods for executing transitions,
// visualizing the model as SVG, and exporting the model in various formats such as
// JSON, Markdown, and GnoMark.
//
// Key features:
// - Define places, transitions, and arcs with attributes like tokens, capacity, and weight.
// - Simulate state changes in the Petri net using the Execute function.
// - Generate SVG visualizations of the Petri net and its legend.
// - Export the model to JSON and Markdown for integration with other tools.
//
// This package is designed for use in distributed systems modeling, workflow analysis,
// and educational purposes.

package metamodel

import (
	"math"
	"net/url"
	"strings"

	"gno.land/p/demo/ufmt"
)

func HasModelApi(input any) bool {
	if _, ok := input.(*Model); ok {
		return true // Input is a Model
	}
	return false // No Model API found
}

func New(inputs ...any) *Model {
	m := &Model{
		Places:      map[string]Place{},
		Transitions: map[string]Transition{},
		Arrows:      []Arrow{},
	}

	for _, input := range inputs {
		switch v := input.(type) {
		case *Model:
			// Merge another model into the current one
			for label, place := range v.Places {
				m.Places[label] = place
			}
			for label, transition := range v.Transitions {
				m.Transitions[label] = transition
			}
			m.Arrows = append(m.Arrows, v.Arrows...)
		case map[string]Place:
			for label, place := range v {
				m.Places[label] = place
			}
		case map[string]Transition:
			for label, transition := range v {
				m.Transitions[label] = transition
			}
		case []Arrow:
			m.Arrows = append(m.Arrows, v...)
		case map[string]any:
			m.RenderOpts = v
		default:
			continue
		}
	}

	offset := 0
	for label, place := range m.Places {
		place.Offset = offset
		m.Places[label] = place
		offset++
	}

	offset = 0
	for label, transition := range m.Transitions {
		transition.Offset = offset
		m.Transitions[label] = transition
		offset++
	}

	return m
}

// TokenType represents multiple token types as a slice of integers.
type TokenType []int64

func (tt TokenType) String() string {
	if len(tt) == 0 {
		return "[]"
	}
	var sb strings.Builder
	sb.WriteString("[")
	for i, v := range tt {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(ufmt.Sprintf("%d", v))
	}
	sb.WriteString("]")
	return sb.String()
}

// T creates a TokenType from a list of integers or strings.
func T(t ...any) TokenType {
	ts := make(TokenType, len(t))
	for i, v := range t {
		switch v := v.(type) {
		case int:
			ts[i] = int64(v)
		case int64:
			ts[i] = v
		case string:
			ts[i] = 1
		default:
			ts[i] = -1 // Default to -1 for unsupported types.
		}
	}

	return ts
}

// S creates a TokenType state vector from a list of TokenType.
func S(ts ...any) []TokenType {
	state := make([]TokenType, len(ts))
	for i, v := range ts {
		state[i] = T(v)
	}
	return state
}

// Place represents a place in the Petri net.
type Place struct {
	Label    string      // Label of the place.
	Offset   int         // Offset of the place in the Petri net.
	Tokens   TokenType   // Current number of tokens for each type.
	Initial  TokenType   // Initial number of tokens for each type.
	Capacity TokenType   // Maximum capacity for each token type (0 = unlimited).
	X        int         // X coordinate of the place.
	Y        int         // Y coordinate of the place.
	Binding  any // Optional binding for the place.
}

// Arrow represents an arc in the Petri net.
type Arrow struct {
	Source  string      // Source place or transition.
	Target  string      // Target place or transition.
	Weight  TokenType   // Weight for each token type.
	Inhibit bool        // Indicates if the arc inhibits the transition.
	Binding any // Optional binding for the arc.
}

// Transition represents a transition in the Petri net.
type Transition struct {
	Label   string      // Label of the transition.
	Offset  int         // Offset of the transition in the Petri net.
	X       int         // X coordinate of the transition.
	Y       int         // Y coordinate of the transition.
	Binding any // Optional binding for the transition.
}

// Model represents a Petri-Net.
type Model struct {
	RenderOpts  map[string]any // Rendering options for the model.
	Places      map[string]Place       // Map of places.
	Transitions map[string]Transition  // Map of transitions.
	Arrows      []Arrow                // List of arcs.
	Binding     any            // Optional binding for the model.
}

func (model *Model) State() []TokenType {
	state := make([]TokenType, len(model.Places))
	for _, place := range model.Places {
		state[place.Offset] = place.Tokens
	}
	return state
}

// Execute executes a callback if the model transformation is successful.
func (model *Model) Execute(action string, onCommit func(newState []TokenType)) ([]TokenType, bool) {
	if model == nil {
		return nil, false // No model to execute.
	}

	state := model.State()
	newState, ok := Execute(state, model, action)
	if !ok {
		panic("Failed to execute action: " + action + " on model: " + model.ToJson())
	}
	if onCommit != nil {
		onCommit(newState) // Execute the callback if provided.
	}

	return newState, true
}

// TODO: try this out w/ testing
func Execute(state []TokenType, model *Model, action string) ([]TokenType, bool) {
	newState := make([]TokenType, len(state))
	copy(newState, state)

	for _, arc := range model.Arrows {
		if arc.Target == action {
			sourceTokens := model.Places[arc.Source].Tokens
			for i, weight := range arc.Weight {
				if sourceTokens[i] < weight {
					return state, false // Not enough tokens.
				}
				sourceTokens[i] -= weight
			}
		} else if arc.Source == action {
			targetTokens := model.Places[arc.Target].Tokens
			for i, weight := range arc.Weight {
				targetTokens[i] += weight
				if model.Places[arc.Target].Capacity[i] > 0 && targetTokens[i] > model.Places[arc.Target].Capacity[i] {
					return state, false // Exceeds capacity.
				}
			}
		}
	}

	return newState, true
}

func fmtWeight(weight TokenType) (out string) {
	if len(weight) == 0 || weight[0] == 0 {
		return ""
	}
	if len(weight) == 1 {
		out = ufmt.Sprintf("%d", weight[0])
	} else {
		out = ufmt.Sprintf("%v", weight)
	}
	if weight[0] >= 1_000_000 {
		out = ufmt.Sprintf("%dM", weight[0]/1_000_000)
	} else if weight[0] >= 1000 {
		out = ufmt.Sprintf("%dK", weight[0]/1000)
	} else {
		out = ufmt.Sprintf("%d", weight[0])
	}
	return out
}

func (model *Model) CanvasSize() (width, height int) {
	maxX, maxY := 0, 0
	for _, place := range model.Places {
		if place.X > maxX {
			maxX = place.X
		}
		if place.Y > maxY {
			maxY = place.Y
		}
	}
	for _, transition := range model.Transitions {
		if transition.X > maxX {
			maxX = transition.X
		}
		if transition.Y > maxY {
			maxY = transition.Y
		}
	}
	return maxX + 50, maxY + 50 // Add some padding
}

func (model *Model) ToSvg(scale ...float64) string {
	var sb strings.Builder
	width, height := model.CanvasSize()
	var s float64 = 2.0 // Default scale

	if len(scale) > 1 && scale[0] > 0 {
		s = scale[0]
	}

	sb.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%f" height="%d" viewBox="0 0 %d %d">\n`,
		width*int(s), height*int(s), width, height))

	sb.WriteString(`
        <style>
            .place { fill: #f0f0f0; stroke: #000000; stroke-width: 2; }
            .transition { fill: #ffffff; stroke: #000000; stroke-width: 2; }
            .arc { stroke: #000000; stroke-width: 1; }
            .label { font-family: Arial, sans-serif; font-size: 14px; fill: #000000; }
            .label-background { fill: #f0f0f0; stroke: #000000; stroke-width: 1; }
            .tokenSmaller { font-size: 12px; }
        </style>
    `)

	sb.WriteString(`
        <defs>
            <marker id="arrow" markerWidth="22.5" markerHeight="12" refX="9" refY="6.5" orient="auto">
                <path d="M3,1.5 L3,12 L10.5,6 L3,1.5"/>
            </marker>
            <marker id="inhibit" markerWidth="30" markerHeight="16" refX="10" refY="8.5" orient="auto">
                <circle cx="8" cy="9" r="4"/>
            </marker>
        </defs>
    `)

	for _, arrow := range model.Arrows {
		var sourceX, sourceY, targetX, targetY int

		// Determine source coordinates
		if place, ok := model.Places[arrow.Source]; ok {
			sourceX, sourceY = place.X, place.Y
		} else if transition, ok := model.Transitions[arrow.Source]; ok {
			sourceX, sourceY = transition.X, transition.Y
		} else {
			continue // Skip if source is invalid
		}

		// Determine target coordinates
		if place, ok := model.Places[arrow.Target]; ok {
			targetX, targetY = place.X, place.Y
		} else if transition, ok := model.Transitions[arrow.Target]; ok {
			targetX, targetY = transition.X, transition.Y
		} else {
			continue // Skip if target is invalid
		}

		// Calculate shortened coordinates
		dx := targetX - sourceX
		dy := targetY - sourceY
		length := math.Sqrt(float64(dx*dx + dy*dy))
		shortenFactor := 24
		x2 := targetX - int(float64(dx)/length*float64(shortenFactor))
		y2 := targetY - int(float64(dy)/length*float64(shortenFactor))

		marker := "arrow"
		if arrow.Inhibit {
			marker = "inhibit"
		}

		sb.WriteString(ufmt.Sprintf("<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" class=\"arc\" marker-end=\"url(#%s)\" />\n",
			sourceX, sourceY, x2, y2, marker))

		// Add mid-marker circle and weight
		midX := (sourceX + x2) / 2
		midY := (sourceY + y2) / 2

		// format 0.0 K 0.0M etc
		if len(arrow.Weight) == 0 || arrow.Weight[0] == 0 {
			continue // Skip if no weight
		}

		className := "label"
		if arrow.Weight[0] > 1000 {
			className = "tokenSmaller"
		}

		weightStr := fmtWeight(arrow.Weight)
		sb.WriteString(ufmt.Sprintf("<circle cx=\"%d\" cy=\"%d\" r=\"14\" class=\"label-background\" />\n", midX, midY))
		sb.WriteString(ufmt.Sprintf("<text x=\"%d\" y=\"%d\" class=\"%s\">%s</text>\n", midX-11, midY+5, className, weightStr))
	}

	// Draw places
	for _, place := range model.Places {
		// FIXME: label is empty
		sb.WriteString(ufmt.Sprintf("<circle cx=\"%d\" cy=\"%d\" r=\"16\" class=\"place\" />\n", place.X, place.Y))
		sb.WriteString(ufmt.Sprintf("<text x=\"%d\" y=\"%d\" class=\"label\">%s</text>\n", place.X-18, place.Y-20, place.Label))
	}

	// Draw transitions
	for i, transition := range model.Transitions {
		label := ufmt.Sprintf("%s", i)
		sb.WriteString(ufmt.Sprintf("<rect x=\"%d\" y=\"%d\" width=\"30\" height=\"30\" class=\"transition\" />\n", transition.X-15, transition.Y-15))
		sb.WriteString(ufmt.Sprintf("<text x=\"%d\" y=\"%d\" class=\"label\">%s</text>\n", transition.X-15, transition.Y-20, label))
	}

	sb.WriteString("</svg>")
	return sb.String()
}

func (model *Model) LegendDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(model.LegendSvg())
}

func (model *Model) LegendSvg(scale ...float64) string {
	scaleFactor := 1.0
	if len(scale) > 0 && scale[0] > 0 {
		scaleFactor = scale[0]
	}
	var sb strings.Builder
	width, height := 700, 400 // FIXME: calculate based on content size
	sb.WriteString(ufmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%v" height="%v" >\n`, width, height))

	sb.WriteString(`<style>
        .legend { font-family: Arial, sans-serif; font-size: 14px; fill: #000000; }
        .token { width: 20px; height: 20px; }
        .place-label { font-size: 12px; font-weight: bold; fill: #333333; }
        .transition-label { font-size: 12px; font-style: italic; fill: #666666; }
        .arrow-label { font-size: 12px; fill: #444444; }
        .line-odd { fill: #f9f9f9; }
        .line-even { fill: #e9e9e9; }
    </style>`)

	sb.WriteString(`<g class="legend" transform="scale(` + ufmt.Sprintf("%f", scaleFactor) + `)">`)
	y := 40
	lineIndex := 0
	for label, place := range model.Places {
		lineClass := "line-odd"
		sb.WriteString(ufmt.Sprintf(`<rect x="0" y="%d" width="900" height="30" class="%s" />`, y-15, lineClass))
		color := "#f0f0f0" // Default color for places
		sb.WriteString(ufmt.Sprintf(`<circle cx="20" cy="%d" r="10" class="token" fill="%s" />`, y, color))
		sb.WriteString(ufmt.Sprintf(`<text x="40" y="%d" class="place-label">%s</text>`, y+5, label))
		if len(place.Initial) > 0 && place.Initial[0] > 0 {
			sb.WriteString(ufmt.Sprintf(`<text x="120" y="%d" class="place-label">%s</text>`, y+5, place.Initial.String()))
		} else {
			sb.WriteString(ufmt.Sprintf(`<text x="120" y="%d" class="place-label">-</text>`, y+5))
		}
		y += 30
		lineIndex++
	}

	txShortLabels := make(map[string]string)

	for label, transition := range model.Transitions {
		lineClass := "line-even"
		sb.WriteString(ufmt.Sprintf(`<rect x="0" y="%d" width="900" height="30" class="%s" />`, y-5, lineClass))
		color := "#999999" // Default color for transitions
		sb.WriteString(ufmt.Sprintf(`<rect x="13" y="%d" width="20" height="20" class="token" fill="%s" />`, y, color))
		sb.WriteString(ufmt.Sprintf(`<text x="42" y="%d" class="transition-label">%s</text>`, y+15, label+": "+transition.Label))
		y += 30
		lineIndex++
		txShortLabels[transition.Label] = label
	}

	y += 20

	for _, arrow := range model.Arrows {
		lineClass := "line-odd"
		if lineIndex%2 == 0 {
			lineClass = "line-even"
		}
		sb.WriteString(ufmt.Sprintf(`<rect x="0" y="%d" width="900" height="20" class="%s" />`, y-10, lineClass))
		sourceLabel := arrow.Source
		targetLabel := arrow.Target
		if place, ok := model.Places[arrow.Source]; ok && place.Label != "" {
			sourceLabel = place.Label
		} else if transition, ok := model.Transitions[arrow.Source]; ok && transition.Label != "" {
			sourceLabel = arrow.Source
		}
		if place, ok := model.Places[arrow.Target]; ok && place.Label != "" {
			targetLabel = place.Label
		} else if transition, ok := model.Transitions[arrow.Target]; ok && transition.Label != "" {
			targetLabel = arrow.Target
		}
		arrowType := "→"
		if arrow.Inhibit {
			arrowType = "⦸"
		}
		sb.WriteString(ufmt.Sprintf(`<text x="10" y="%d" class="arrow-label">%s %s %s</text>`, y+3, sourceLabel, arrowType, targetLabel))
		weightStr := fmtWeight(arrow.Weight)
		if weightStr != "" {
			sb.WriteString(ufmt.Sprintf(`<text x="200" y="%d" class="arrow-label">%s</text>`, y+3, weightStr))
		} else {
			sb.WriteString(ufmt.Sprintf(`<text x="200" y="%d" class="arrow-label">-</text>`, y+3))
		}
		y += 20
		lineIndex++
	}
	sb.WriteString(`</g>`)
	sb.WriteString("</svg>")
	return sb.String()
}

func (model *Model) ToDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(model.ToSvg())
}

// wrap the thumbnail data URL in a function scale 1/10
func (model *Model) ThumbnailDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(model.ThumbnailSvg("140", "140"))
}

func (model *Model) ThumbnailSvg(w, h string) string {
	dataUrl := model.ToDataUrl()
	return `<svg width="` + w + `" height="` + h + `" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="none" stroke="#facade"/>
		<image href="` + dataUrl + `" width="` + w + `" height="` + h + `"/>
	</svg>`
}

func (model *Model) ToMarkdown() string {
	var sb strings.Builder

	sb.WriteString("![Petri Net](")
	sb.WriteString(model.ToDataUrl())
	sb.WriteString(")\n\n")

	sb.WriteString("![Legend](")
	sb.WriteString(model.LegendDataUrl())
	sb.WriteString(")\n\n")

	return sb.String()
}

// ToGnoMark converts the Petri net model to GnoMark format json string.
func (model *Model) ToGnoMark(h WebHost) string {
	var sb strings.Builder
	sb.WriteString("{\n")
	sb.WriteString(`  "gnomark": "petri-net",` + "\n")
	sb.WriteString(`  "net": ` + model.ToJson() + "\n")
	sb.WriteString(`  "cdn": { "static": "` + h.Cdn() + `" },` + "\n")
	sb.WriteString("}")
	return sb.String()
}

// ToJson converts the Petri net model to a JSON string.
func (model *Model) ToJson() string {
	var sb strings.Builder
	sb.WriteString("{\n")
	sb.WriteString(`  "modelType": "PetriNet",` + "\n")
	sb.WriteString(`  "version": "v1",` + "\n")
	sb.WriteString(`  "tokens": ["black"],` + "\n")
	sb.WriteString(`  "places": {` + "\n")
	placeCount := len(model.Places)
	i := 0
	for label, place := range model.Places {
		sb.WriteString(ufmt.Sprintf(`    "%s": { "offset": %d, "initial": %v, "capacity": %v, "x": %d, "y": %d }`,
			label, place.Offset, place.Initial, place.Capacity, place.X, place.Y))
		if i < placeCount-1 {
			sb.WriteString(",\n")
		} else {
			sb.WriteString("\n")
		}
		i++
	}
	sb.WriteString("  },\n")
	sb.WriteString("  \"transitions\": {\n")
	transitionCount := len(model.Transitions)
	i = 0
	for label, transition := range model.Transitions {
		sb.WriteString(ufmt.Sprintf(`    "%s": { "x": %d, "y": %d }`,
			label, transition.X, transition.Y))
		if i < transitionCount-1 {
			sb.WriteString(",\n")
		} else {
			sb.WriteString("\n")
		}
		i++
	}
	sb.WriteString("  },\n")
	sb.WriteString("  \"arcs\": [\n")
	for i, arc := range model.Arrows {
		sb.WriteString(ufmt.Sprintf(`    { "source": "%s", "target": "%s", "weight": %v`,
			arc.Source, arc.Target, arc.Weight))
		if arc.Inhibit {
			sb.WriteString(", \"inhibit\": true")
		}
		sb.WriteString(" }")
		if i < len(model.Arrows)-1 {
			sb.WriteString(",\n")
		} else {
			sb.WriteString("\n")
		}
	}
	sb.WriteString("  ]\n")
	sb.WriteString("}")
	return sb.String()
}

type WebHost struct {
	Base string
	Tag  string
	Path string
}

func (h *WebHost) Cdn() string {
	return h.Base + h.Tag + h.Path
}

type SourceProvider = func(path string) string

func templateHtml(key, value string, s SourceProvider, path string) (out string) {
	out = strings.ReplaceAll(htmlContent, key, value)
	return strings.ReplaceAll(out, "{SOURCE}", s(path))
}

func Html(w *WebHost, s SourceProvider, path string) string {
	return templateHtml("{CDN}", w.Cdn(), s, path)
}

var htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="{CDN}petri-net.js"></script>
    <title>pflow | metamodel</title>
</head>
<body>
    <petri-net>
    {SOURCE}
    </petri-net>
</body>
</html>
`
