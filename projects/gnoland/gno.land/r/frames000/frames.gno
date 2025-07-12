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
- You can build your own frames by implementing a public interface for your realm.
` + "```\n" +
`func RenderFrame(path string) string { // frame.gno.services calls this public function
 	return frame // json encoded frame
 }` +
"\n```" + `
- The frame should return a JSON object with the following structure:

` + "```\n" + frame + "\n```" + `
- Check out our static files hosted by jsDeliver: [static](https://cdn.jsdelivr.net/gh/allinbits/gnoserve@frame/static/)
### Learn More
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
