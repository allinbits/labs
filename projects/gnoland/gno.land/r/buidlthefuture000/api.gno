package events

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
)

var (
	api              = &Api{}
	registry         = avl.NewTree()
	displayPaths     []string
	realmAllowPrefix []string
)

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/") // must be in realm sub-path
}

func hasAllowedPrefix() bool {
	prevRealm := std.PreviousRealm().PkgPath()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(prevRealm, callerPath) {
			return true
		}
	}
	return prevRealm == ""
}

func assertAccess() {
	if !hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}

func Render(path string) string {
	return api.Render(path)
}

// Register registers a ContentBlock function - use this to override the default rendering
func Register(key string, block func(path string) string) {
	api.Register(key, block)
}

type Api struct{}

func (*Api) Register(key string, block func(path string) string) {
	assertAccess()
	if _, ok := registry.Get(key); ok {
		// TODO emit update event
	}
	registry.Set(key, block)
}

func (*Api) Render(path string) string {
	sb := strings.Builder{}
	for _, key := range displayPaths {
		if block, ok := registry.Get(key); ok {
			sb.WriteString("### " + key + "\n")
			sb.WriteString(block.(func(path string) string)(path))
			// TODO: also render TermSet
			sb.WriteString("\n")
		}
	}
	return sb.String()
}
