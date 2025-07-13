package gnocap

import (
	"net/url"
	"strings"

	"gno.land/p/demo/ufmt"
)

const GridWidth = 51 // FIXME: can this be 50?

type Bounds struct {
	X1 int
	Y1 int
	X2 int
	Y2 int
}

type ColorPixel struct {
	X int
	Y int
	R uint8
	G uint8
	B uint8
}

type PixelImage struct {
	Pixels []ColorPixel
	Bounds
}

func (image *PixelImage) SetPixel(x, y, r, g, b int) {
	if x < image.Bounds.X1 || x > image.Bounds.X2 || y < image.Bounds.Y1 || y > image.Bounds.Y2 {
		return
	}
	if r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 {
		return
	}
	image.Pixels[x*GridWidth+y] = ColorPixel{
		X: x,
		Y: y,
		R: uint8(r),
		G: uint8(g),
		B: uint8(b),
	}
}

func (image *PixelImage) ToMarkdown() string {
	return "![stackdump-bmp](data:image/svg+xml;utf8," + url.PathEscape(image.ToSvg()) + ")"
}

func (image *PixelImage) ToSvg() string {
	tileSize := 1

	var sb strings.Builder

	// Compute viewbox
	var maxX, maxY int
	var minX, minY int
	for _, p := range image.Pixels {
		if p.R == 0 && p.G == 0 && p.B == 0 {
			continue // Skip black pixels
		}
		if minX == 0 && minY == 0 {
			minX = p.X
			minY = p.Y
		}
		if p.X < minX {
			minX = p.X
		}
		if p.Y < minY {
			minY = p.Y
		}
		if p.X > maxX {
			maxX = p.X
		}
		if p.Y > maxY {
			maxY = p.Y
		}
	}
	minX = minX * tileSize
	minY = minY * tileSize
	width := (maxX - minX + 1) * tileSize
	height := (maxY - minY + 1) * tileSize

	sb.WriteString(ufmt.Sprintf(
		`<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="%d %d %d %d">`,
		minX, minY, width, height))

	sb.WriteString(`
  <defs>
    <rect id="p" width="1" height="1" rx="0.2" ry="0.2"/>
  </defs>
  <style>
`)

	colorClassMap := make(map[string]string)
	classCount := 0
	for _, p := range image.Pixels {
		key := ufmt.Sprintf("%d_%d_%d", p.R, p.G, p.B)
		if _, ok := colorClassMap[key]; !ok {
			className := ufmt.Sprintf("c%d", classCount)
			colorClassMap[key] = className
			classCount++
			sb.WriteString(ufmt.Sprintf("  .%s { fill: rgb(%d,%d,%d); }\n", className, p.R, p.G, p.B))
		}
	}

	sb.WriteString("  </style>\n")

	sb.WriteString("<g id=\"bmp-image\" transform=\"translate(0.5,0)\">\n")
	for _, p := range image.Pixels {
		if p.R == 0 && p.G == 0 && p.B == 0 {
			continue // Skip black pixels
		}
		key := ufmt.Sprintf("%d_%d_%d", p.R, p.G, p.B)
		className := colorClassMap[key]
		sb.WriteString(ufmt.Sprintf(
			`  <use href="#p" x="%d" y="%d" class="%s"/>`+"\n",
			p.X*tileSize, p.Y*tileSize, className))
	}
	sb.WriteString("</g>\n")

	sb.WriteString(`</svg>`)

	return sb.String()
}

const heading = `
package %s

import (
	image "gno.land/r/stackdump000/bmp"
)

type %s struct {}

var _ image.ImageApi = &%s{}

func init() {
    image.Register("%s", %s{})
}

func (%s) Pixels(p image.PixelSetter) {
`

const footer = `
}
`

// Source generates exports of images to use in gno source files.
// NOTE: during development, this can be used to generate a source file that doesn't set pixels out of bounds
func (image *PixelImage) Source(name string) string {

	objectName := strings.Title(name)
	src := ufmt.Sprintf(heading, name, objectName, objectName, name, objectName, objectName)
	livePixels := 0
	for i := 0; i < len(image.Pixels); i++ {
		p := image.Pixels[i]
		if p.R == 0 && p.G == 0 && p.B == 0 {
			continue // Skip black pixels
		}
		src += ufmt.Sprintf("\tp(%d, %d, %d, %d, %d)\n", p.X, p.Y, p.R, p.G, p.B)
		livePixels++
	}
	src += ufmt.Sprintf("\t// Found %d/%d live Pixels", livePixels, len(image.Pixels)) + footer
	return src
}
