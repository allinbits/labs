package events

import (
	"strings"

	"gno.land/p/demo/avl"
)

var (
	app          = &App{}
	registry     = avl.NewTree() // registry of ContentBlock functions
	displayPaths []string
)

type App struct{}

func (*App) Register(key string, block func(string) string) {
	assertAccess()
	registry.Set(key, block)
}

func (*App) Render(path string) string {
	sb := strings.Builder{}
	for _, key := range displayPaths {
		if block, ok := registry.Get(key); ok {
			sb.WriteString("### " + key + "\n")
			sb.WriteString(block.(func(string) string)(path))
			sb.WriteString("\n")
		}
	}
	return sb.String()
}
