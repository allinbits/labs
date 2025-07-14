package metamodel

import (
	"std"
	"strings"

	"gno.land/p/demo/avl"
)

var (
	registry         = avl.NewTree()
	realmAllowPrefix = []string{}
	displayPaths     = ""
)

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/") // must be in realm sub-path
}

type ContentBlock = func(path string) string

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
func Register(cur realm, key string, block ContentBlock) {
	assertAccess()
	register(key, block)
}

func register(key string, block ContentBlock) {
	if _, ok := registry.Get(key); ok {
		// TODO emit update event
	}
	if strings.Contains(displayPaths, key) {
		panic("Invalid Key, matches previous content block" + key)
	}
	displayPaths += key + "\n"
	registry.Set(key, block)
}

func Content(cur realm, key string, path string) string {
	if block, ok := registry.Get(key); ok {
		return block.(ContentBlock)(path)
	}
	panic("Key not found: " + key)
}

func upcaseWords(s string) string {
	words := strings.Fields(s)
	for i, word := range words {
		if len(word) > 0 {
			words[i] = strings.ToUpper(string(word[0])) + word[1:]
		}
	}
	return strings.Join(words, " ")
}

func Render(path string) string {
	sb := strings.Builder{}
	keys := strings.Split(displayPaths, "\n")

	for _, key := range keys {
		if block, ok := registry.Get(key); ok {
			sb.WriteString("### " + upcaseWords(key) + "\n")
			sb.WriteString(block.(ContentBlock)(path))
			sb.WriteString("\n")
		}
	}
	return sb.String()
}
