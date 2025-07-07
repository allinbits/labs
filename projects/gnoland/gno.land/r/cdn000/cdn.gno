package cdn

import (
	"net/url"
	"std"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/txlink"
)

var (
	registry = avl.NewTree()
	admins   = avl.NewTree()
)

type Admin struct {
	Address string
}

type BannedHost struct {
	Path string
}

func banHost(path string) {
	registry.Set(path, &BannedHost{Path: path})
}

func IsAdmin() bool {
	addr := std.OriginCaller().String()
	_, ok := admins.Get(addr)
	return ok
}

func assertAccess() {
	if !IsAdmin() {
		panic("access denied")
	}
}

func setAdmin(address string) {
	admins.Set(address, &Admin{Address: address})
}

func init() {
	setAdmin("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz")
	banHost("https://cdn.example.com/gh/pflow-xyz/pflow-app@main/static/")
	banHost("https://cdn.example.com/gh/allinbits/gnoserve@main/static/")
	//banHost("https://cdn.jsdelivr.net/gh/pflow-xyz/pflow-app@main/static/")
}

var requestBanForm = `
<gno-form>
<gno-input name="host" placeholder="https://cdn.example.com/gh/user/repo@main/static/" />
<gno-input name="msg" placeholder=" has a security issue: XXX" />
</gno-form>
`

func renderConfirmation(path string) string {
	var sb strings.Builder
	fullURL := std.CurrentRealm().PkgPath() + path
	u, err := url.Parse(fullURL)
	if err != nil {
		panic("invalid path in renderConfirmation: " + path)
	}

	q := u.Query()
	host := q.Get("host")
	msg := q.Get("msg")

	host, _ = url.QueryUnescape(host)
	msg, _ = url.QueryUnescape(msg)

	if !IsValidHost(host) {
		sb.WriteString("# Invalid Host\n")
		sb.WriteString("The host you provided is not valid. Please ensure it starts with `https://` and ends with `/static/`.\n")
		sb.WriteString("You provided: `" + host + "`\n\n")
		return sb.String()
	}

	sb.WriteString("## Request to ban CDN host\n")
	sb.WriteString("You are requesting to ban the following host:\n\n")
	sb.WriteString("- " + host + "\n\n")
	sb.WriteString("Reason: " + msg + "\n\n")
	sb.WriteString("To submit -  sign request by clicking the button below.\n\n")
	sb.WriteString(confirmButton(host, msg))
	return sb.String()
}

func confirmButton(host, msg string) string {
	label := "Confirm Ban"
	link := txlink.NewLink("RequestBan").AddArgs("host", host, "msg", msg).URL()
	svgButton := button("svg", map[string]interface{}{
		"width":    200,
		"height":   40,
		"fontSize": 16,
		"label":    label,
	})
	dataUrl := "data:image/svg+xml;utf8," + url.PathEscape(svgButton)

	return "[![" + label + "](" + dataUrl + ")](" + link + ")"
}

func Render(path string) string {
	if strings.Contains(path, "?") {
		return renderConfirmation(path)
	}
	var sb strings.Builder
	sb.WriteString("# cdn000 - CDN blocklist\n")
	sb.WriteString("This is a list of banned CDN hosts and admins who can manage them.\n\n")
	sb.WriteString("CDN paths that are not banned are usable via the gno_cdn proxy.\n")

	sb.WriteString(requestBanForm)

	sb.WriteString("## CDN Admins\n")
	admins.IterateByOffset(0, admins.Size(), func(key string, value interface{}) bool {
		sb.WriteString("\n- [" + key + "](/u/" + key + ")")
		return false
	})
	sb.WriteString("\n\n")
	sb.WriteString("## Banned CDN Hosts\n")
	registry.IterateByOffset(0, registry.Size(), func(key string, value interface{}) bool {
		sb.WriteString("\n- " + key)
		return false
	})

	return sb.String()
}

// BanHost adds a host to the banned list, only callable by an admin.
func BanHost(cur realm, host string) {
	assertAccess()
	host, _ = url.QueryUnescape(host)
	if !IsValidHost(host) {
		panic("invalid host")
	}

	std.Emit("BanHost", "host", host)
	banHost(host)
}

func isValidFormat(host string) bool {
	if !strings.HasPrefix(host, "https://") {
		return false
	}

	if !strings.HasSuffix(host, "/static/") {
		return false
	}

	return true
}

func IsValidHost(host string) bool {
	return isValidFormat(host) && !IsBannedHost(host)
}

// IsBannedHost checks if a host is banned in the CDN registry.
func IsBannedHost(host string) bool {
	host, _ = url.QueryUnescape(host)
	_, banned := registry.Get(host)
	return banned
}

// RequestBan sends a request to ban a host, only callable by an admin.
func RequestBan(cur realm, host string, msg string) {
	host, _ = url.QueryUnescape(host)
	msg, _ = url.QueryUnescape(msg)
	if !isValidFormat(host) {
		panic("invalid host")
	}
	if IsBannedHost(host) {
		panic("host is already banned")
	}
	std.Emit("RequestBan", "host", host, "msg", msg)
}

func button(format string, props map[string]interface{}) string {
	if format != "svg" {
		panic("button: format must be 'svg'")
	}

	width := getIntProp(props, "width", 200)
	height := getIntProp(props, "height", 40)
	fontSize := getIntProp(props, "fontSize", 16)
	label := getStringProp(props, "label", "Button")

	return `<svg xmlns="http://www.w3.org/2000/svg" width="` + ufmt.Sprintf("%d", width) + `" height="` + ufmt.Sprintf("%d", height) + `">
    <foreignObject x="0" y="0" width="` + ufmt.Sprintf("%d", width) + `" height="` + ufmt.Sprintf("%d", height) + `">
        <body xmlns="http://www.w3.org/1999/xhtml">
            <button style="width: 100%; height: 100%; font-size: ` + ufmt.Sprintf("%d", fontSize) + `px;">
                ` + label + `
            </button>
        </body>
    </foreignObject>
</svg>`
}

func getIntProp(props map[string]interface{}, key string, defaultValue int) int {
	if val, ok := props[key]; ok {
		if intVal, ok := val.(int); ok {
			return intVal
		}
	}
	return defaultValue
}

func getStringProp(props map[string]interface{}, key string, defaultValue string) string {
	if val, ok := props[key]; ok {
		if strVal, ok := val.(string); ok {
			return strVal
		}
	}
	return defaultValue
}
