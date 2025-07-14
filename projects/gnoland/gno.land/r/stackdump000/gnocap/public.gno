package gnocap

import (
	"strconv"
	"strings"
)

var (
	grid = map[string]PixelImage{}
	cols = []string{"A", "B", "C", "D", "E"}
	rows = []string{"0", "1", "2", "3", "4"}
	quad = []string{"z", "y", "x", "w"}

	gx   = 25 // grid size to populate
	gy   = 25
	mult = 2
)

func pixelColors() (pixels []ColorPixel) {
	for x := 0; x < gx; x++ {
		for y := 0; y < gy; y++ {
			r := 1
			g := x * 50 % 256
			b := 32
			pixels = append(pixels, ColorPixel{
				X: x,
				Y: y,
				R: uint8(r),
				G: uint8(g),
				B: uint8(b),
			})
		}
	}
	return pixels
}

func init() {
	pixels := pixelColors()

	for _, col := range cols {
		for _, row := range rows {
			for _, q := range quad {
				grid[col+row+q] = PixelImage{
					Pixels: pixels,
					Bounds: Bounds{ // REVIEW: scale to grid size
						X1: 0,
						Y1: 0,
						X2: 50,
						Y2: 50,
					},
				}
			}
		}
	}
}
func RenderFrame(path string) string {
	//return Grid(path)
	return `{ "gnomark": "gno-frame", "frame": {
        "title": "Gnocap",
        "description": "Gnocap grid"
    }`
}

func Render(path string) string {
	switch path {
	case "svg":
		return SvgGrid()
	case "intro":
		return intro
	case "body":
		return body
	case "":
		return intro + controls + body
	default:
		return Grid(path)
	}

}

func renderGridElement(path string, format string) string {
	el, ok := grid[path]
	if !ok {
		return "Grid not found: " + path
	}

	if format == "svg" {
		return el.ToSvg()
	}
	return el.ToMarkdown()
}

func Grid(p string) string {
	path := getPath(p)
	format := getFormat(p)
	if path == "" {
		return "No grid specified"
	} else {
		return renderGridElement(path, format)
	}
}

func getPath(input string) string {
	parts := strings.Split(input, ":")
	if len(parts) > 0 {
		return parts[0]
	}
	return ""
}

// Build out entire grid
func SvgGrid() string {
	var sb strings.Builder
	sb.WriteString(`<svg width="100%" height="100%" viewBox="0 0 250 250" xmlns="http://www.w3.org/2000/svg">`)
	for c, col := range cols {
		for r, row := range rows {
			for _, q := range quad {
				x := c * 25
				y := r * 25
				switch q {
				case "x":
					x = x + 25
				case "y":
					y = y + 25
				case "w":
					x = x + 25
					y = y + 25
				}
				sb.WriteString(`<image x="` + strconv.Itoa(x) + `" y="` + strconv.Itoa(y) + `" width="25" height="25" href="/svg/r/stackdump000/gnocap:` + col + row + q + `:svg"/>`)
			}
		}
	}
	sb.WriteString(`</svg>`)
	return sb.String()
}
