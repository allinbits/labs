# 📦 Gnomark Frames

```json
{
    "gnomark": "gno-frame",
    "frame": {
        "title": "Frames",
        "description": "A simple frame example",
        "logo": "/static/logo.svg",
        "icon": "/static/favicon.ico"
    }
}
```

---

## 🛠 How to Create a Frame

### 1. Add a manifest to a GitHub repository you control

```txt
/gh/user/repo@main/static/gnomark.json
```

Populate it with the minimum required fields to bootstrap frame rendering:

```json
{
    "gnomark": "gno-frame",
    "frame": {
        "title": "Frames",
        "description": "A simple frame example",
        "logo": "/static/logo.svg",
        "icon": "/static/favicon.ico"
    }
}
```

---

### 2. Publish frame content to GitHub repository

```txt
/gh/user/repo@main/static/gno-frame.js  // defines HTML element
/gh/user/repo@main/static/logo.svg      // logo for frame (SVG preferred, 400x400)
/gh/user/repo@main/static/favicon.ico   // favicon for frame
```

---

### 3. Create an on-chain frame entrypoint

Example: [`/r/frames000:frame`](/r/frames000:frame)

```go
func Render(path string) string {
    if path == "frame" {
        return frame // json content
    } else {
        return index // markdown
    }
}
```

---

### 4. Access via Gno CDN Webservice

Example: [`/frame/r/frames000`](/frame/r/frames000)

The CDN locates assets and frames content using an HTML custom element:

```html
<!DOCTYPE html>
<html>
<head>
    <!-- JS file path is set using gnomark.json & loaded by CDN proxy -->
    <script src="/gh/user/repo@main/static/gno-frame.js"></script>
</head>
<body>
    <!-- tag name is determined by gnomark type -->
    <gno-frame>
        {json content returned by render :frame}
    </gno-frame>
</body>
</html>
```

---

### 5. Update Live Data on Frame Realm

> Data is merged with static copy on the CDN.  
> Static content = off-chain.

```json
{
    "gnomark": "gno-frame",
    "frame": {
        "logo": "/static/logo2.svg" 
    },
    "cdn": {
        "static": "https://cdn.example.com/gh/user/repo@main/static/"
    }
}
```

> Notice that the `cdn.static` field is used to set the static content URL.
> the `gnomark` value must match the `/static/gnomark.json` file.

---

### 🚀 FUTURE: Extensible Gno-Mark Types

- Any name valid as an HTML Custom Element is allowed.
- CDN content is moderated using a blocklist: [`/r/cdn000`](/r/cdn000)