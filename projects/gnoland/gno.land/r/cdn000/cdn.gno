package cdn

import (
	"std"
    "strings"
	"gno.land/p/demo/avl"
	"gno.land/p/moul/txlink"
)

type App struct{}

var (
	app      = &App{}
	registry = avl.NewTree()
	admins  = avl.NewTree()
)

type Admin struct {
    Address string
}

type Host struct {
    Path string
}

func setHost(path string) {
    registry.Set(path, &Host{Path: path})
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
    admins.Set(address, &Admin{ Address: address })
}

func init() {
    registry.Set("gno.land/static/", true)
}

func (*App) Name() string {
	return "cdn"
}

func (*App) Version() string {
	return "0.0.1"
}

func (*App) Render(path string) string {
    _ = path
	return "[IsAdmin](" + txlink.NewLink("IsAdmin").URL() + ")"
}

func AddStaticHost(host string) {
	registry.Set(host, true)
}

func IsValidHost(host string) bool {
    if !strings.HasSuffix(host, "/static/") {
        return false
    }
    _, ok := registry.Get(host)
    return ok
}

func Render(path string) string {
    return app.Render(path)
}