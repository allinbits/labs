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

### How to create a frame

1. add manifest to a github repository you control
` + "```" + `
/gh/user/repo@main/static/gnomark.json
` + "```" + `

populate with minimum required fields to bootstrap frame rendering:

` + "```" + `
// data needed to bootstrap frame, point to cdn and declare gnomark type
` + frame + `
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
    <!-- js file path is set using gnomark.json & is loaded by proxy through the CDN service -->
    <script src="/gh/user/repo@main/static/gno-frame.js"></script>
</head>
<body>
<!-- tag name is determined by gnomark type -->
<gno-frame>
 {json content returned by render :frame}
</gno-frame>
</body>
</html>
` + "```" + `

5. update live data on frame realm

NOTE: Data is merged w/ static copy on the CDN
- live copy can specify the 'live' cdn path
- Vocabulary Tip: 'static' content also implies data is off-chain

` + "```" + `
{
    "gnomark": "gno-frame", // just one of many gnomark types
    "frame": { // custom fields for this gnomark type
        "logo": "/static/logo2.svg", // updated logo
    },
    "cdn": { // a common field for all gnomark types
        "static": "https://cdn.example.com/gh/user/repo@main/static/"
    }

}
` + "```" + `

### FUTURE: gno-mark types are extensible
Any name that is also compatible as a valid HTML Custom Element name can be used.

CDN content is moderated using a blocklist found at [/r/cdn000](/r/cdn000).

`

func Render(path string) string {
	if path == "frame" {
		return frame
	} else {
		return index
	}
}
