package frames

var frame = `
{
    "gnomark": "gno-frame",
    "frame": {
        "title": "Frames",
        "description": "A simple frame example",
        "logo": "/static/logo.svg",
        "icon": "/static/favicon.ico"
    }
}
`

var index = `
## Gnomark Frames
This is a simple example of a Gnomark frame.

Use the frame: [/frame/r/frames000](https://127.0.0.1:8080/frame/r/frames000)

You can build your own frames using GnoLand's Gnomark format.

See the [README.md]($source&file=README.md) for more information.
`

func RenderFrame(path string) string {
	return frame
}

func Render(path string) string {
	if path == "frame" {
		return frame
	} else {
		return index
	}
}
