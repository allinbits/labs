package cdn

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
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

func Render(path string) string {
    var sb strings.Builder
    // print admins
    sb.WriteString("# cdn000 - CDN blocklist\n")
    sb.WriteString("This is a list of banned CDN hosts and admins who can manage them.\n\n")
    sb.WriteString("CDN paths that are not banned are usable via the gno_cdn proxy.\n")

    sb.WriteString("## CDN Admins\n")
    admins.IterateByOffset(0, admins.Size(), func(key string, value interface{}) bool {
        sb.WriteString("\n- [" + key + "](/u/" + key + ")")
        return false
    })
    sb.WriteString("\n\n")
    sb.WriteString("## Banned CDN Hosts\n")
    registry.IterateByOffset(0, registry.Size(), func(key string, value interface{}) bool {
        sb.WriteString("\n- " +key)
        return false
    })

    return sb.String()
}

// BanHost adds a host to the banned list, only callable by an admin.
func BanHost(_ realm , host string) {
    assertAccess()
	registry.Set(host, true)
}

func IsValidHost(host string) bool {
	if !strings.HasPrefix(host, "https://") {
        return false
    }

	// by convention hosts must serve data from "/static/"
	if !strings.HasSuffix(host, "/static/") {
		return false
	}

	return !IsBannedHost(host)
}

func IsBannedHost(host string) bool {
    _, banned := registry.Get(host)
    return banned
}

func RequestBan(_ realm, host string, msg string) {
    if IsBannedHost(host) {
        panic("host is already banned")
    }
    // emit event to request a ban
    std.Emit("action", "RequestBan", "host", host, "msg",  msg)
}