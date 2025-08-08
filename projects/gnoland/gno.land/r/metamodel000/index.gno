package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var (
	renderOpts = map[string]interface{}{
		"dev": map[string]interface{}{
			"Title":       "Metamodel000",
			"Description": "Metamodel Public Registry",
			"Version":     "0.0.1",
			"Date":        "2023-10-01",
		},
	}

	// consider any path that ends with /metamodel/
	authorizedPaths = []string{
		"gno.land/r/metamodel000",
		"gno.land/p/metamodel000",
		"", // account holder wallet
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
