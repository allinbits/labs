package home

var index = `
- [BMP - Bitmap Image Library](/r/stackdump000/bmp) - pixelated images on gno
- [Feed - RSS Feed Service](/r/stackdump000/feed) - an index of pixel images as a feed (WIP)
- [Gnocap - Gno Package Manager](/r/stackdump000/gnocap) - a 250x250 grid of pixels (WIP)
`

func Render(path string) string {
	return index
}
