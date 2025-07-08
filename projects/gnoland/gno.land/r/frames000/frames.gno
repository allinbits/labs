package frames

var frame = `
{
    "gnomark": "gno-frame",
    "frame": {
        "title": "Frames",
        "description": "A simple frame example",
        "author": "Gno.land",
        "version": "0.1.0"
    }
}
`

var index = `
1. add manifest to github repository
` + "```" + `
/gh/user/repo@main/static/gnomark.json
` + "```" + `

populate with minimum required fields to bootstrap frame rendering:

` + "```" + `
// data needed to bootstrap frame, point to cdn and declare gnomark type

{
    "gnomark": "gno-frame",
    "frame": {
        "title": "Frames",
        "description": "A simple frame example",
        "logo": "/static/logo.svg",
        "icon": "/static/favicon.ico"
    }
}
` + "```" + `

2. publish frame content to github repository
` + "```" + `
/gh/user/repo@main/static/gno-frame.js // defines html element
/gh/user/repo@main/static/logo.svg     // logo for frame (svg preferred) 400x400
/gh/user/repo@main/static/favicon.ico  // favicon for frame
` + "```" + `


3. create an on-chain frame entrypoint that expects frame arg [/r/frames000:frame](/r/frames000:frame)

` + "```" + `
func Render(path string) string {
    if path == "frame" {
        return frame // json content
    } else {
        return index // markdown
    }
}
` + "```" + `

4. access via gno_cdn webservice  [/frame/r/frames000](/frame/r/frames000).

CDN webservice is used to locate the assets and frame the content using an HTML Custom Element.

` + "```" + `
<!DOCTYPE html>
<html>
<head>
    <!-- js file path is determined by gnomark.json -->
    <script src="https://cdn.example.com/gn/user/repo@main/static/gno-frame.js"></script>
</head>
<body>
<gno-frame>
 {json content returned by render :frame}
</gno-frame>
</body>
</html>
` + "```"

func Render(path string) string {
	if path == "frame" {
		return frame
	} else {
		return index
	}
}
