package frames

var frame = `
{
    "gnomark": "gno-frame",
    "frame": {
        "title": "Frames",
        "description": "A simple frame example",
        "logo": "logo.svg",
        "icon": "favicon.ico",
        "version": "0.1.0",
        "name": "GnoFrame",
        "iconUrl": "favicon-32x32.png",
        "homeUrl": "https://gno.land",
        "imageUrl": "android-chrome-512x512.png",
        "buttonTitle": "GnoFrame",
        "splashImageUrl": "",
        "splashBackgroundColor": "#ffffff"
    },
    "cdn": { "static": "/gh/allinbits/gnoserve@frame/static/" }
}
`

var index = `
## Gnomark Frames
This is a simple example of a Gnomark frame.

### Simple Frame Example

- Use the frame: [/frame/r/frames000](http://127.0.0.1:8080/frame/r/frames000)

### How to Build Frames

` + "```\n" + frame + "\n```" + `
- You can build your own frames using GnoLand's Gnomark format.
    - See the [README.md](/r/frames000/$source&file=README.md) for more information.
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
