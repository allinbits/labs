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
		},
	}

	// consider any path that ends with /metamodel/
	authorizedPaths = []string{
		"gno.land/r/metamodel000",
		"", // EOA - externally owned account
	}

	registry = mm.NewRegistry(authorizedPaths, renderOpts)
)
func init() {
    codex := mm.Tutorial()
    keywords := []string{"modeling101", "modelCitizen"}
    register("Metamodel Codex", codex, keywords...)
}

func Register(cur realm, key string, m *mm.Model) {
	registry.Register(key, m)
}

// REVIEW: could we remove this?
func register(key string, m *mm.Model, kw ...string) {
	registry.Register(key, m, kw...)
}

func Render(path string) string {
	return registry.Render(path)
}
