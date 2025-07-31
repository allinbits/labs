package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var (
	renderOpts = map[string]interface{}{
		"Title":       "Metamodel000",
		"Description": "A metamodel for Gno.land, providing various models and examples.",
		"Author":      "Gno.land Team",
		"Version":     "0.0.1",
		"Date":        "2023-10-01",
	}

	authorizedPaths = []string{
		"gno.land/r/metamodel000",
		"gno.land/p/metamodel000",
		"",
	}

	registry = mm.NewRegistry(authorizedPaths, renderOpts)
)

func Register(cur realm, key string, obj interface{}) {
	registry.Register(key, obj)
}

func register(key string, obj interface{}) {
	registry.Register(key, obj)
}

func Render(path string) string {
	return registry.Render(path)
}
