package events

import (
	"std"
	"strings"
	"gno.land/p/demo/avl"
)

var (
    registry        = avl.NewTree() // registry of ContentBlock functions
    displayPaths    []string
    realmAllowPrefix []string
)

func init() {
    allowPatchesFromSubRealms()
}

type ContentBlock = func(path string) string

func allowPatchesFromSubRealms() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/") // must be in realm sub-path
}

func hasAllowedPrefix() bool {
	prevRealm := std.PreviousRealm()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(prevRealm.PkgPath(), callerPath) {
			return true
		}
	}
	return false
}

func assertAccess() {
	if !hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}
func Register(key string, block ContentBlock) {
	assertAccess()
	register(key, block)
}

func register(key string, block ContentBlock) {
	if _, ok := registry.Get(key); ok {
		// TODO emit update event
	}
	registry.Set(key, block)
}

func Publish(keys ...string) {
    assertAccess()
    if len(keys) == 0 {
        panic("no keys provided to Publish")
    }
    publish(keys...)
}

func publish(keys ...string) {
    for _, key := range keys {
        if block, ok := registry.Get(key); ok {
            block.(ContentBlock)("") // test call with empty path
        } else {
            panic("Key not found: " + key)
        }
    }
    displayPaths = keys
}

func Content(key string, path string) string {
	if block, ok := registry.Get(key); ok {
		return block.(ContentBlock)(path)
	}
	panic("Key not found: " + key)
}

func Render(path string) string {
	sb := strings.Builder{}
	for _, key := range displayPaths {
		if block, ok := registry.Get(key); ok {
		    sb.WriteString("### "+key+"\n")
			sb.WriteString(block.(ContentBlock)(path))
			// TODO: also render TermSet
			sb.WriteString("\n")
		}
	}
	return sb.String()
}