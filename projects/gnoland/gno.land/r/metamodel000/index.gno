package metamodel

import (
	"strings"

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
	register("Metamodel Codex", mm.Tutorial101(), "modeling101", "modelCitizen")
	register("Metamodel Simulation", mm.Tutorial201(), "modeling201", "petri.jl")
}

func Register(cur realm, key string, m *mm.Model) {
	registry.Register(key, m)
}

func register(key string, m *mm.Model, kw ...string) {
	registry.Register(key, m, kw...)
}

// REVIEW: consider putting this on another page - maybe build a model for the registry
var citizens = `### Become A Model Citizen
![graphic of handwritten word citizins (sic.) crossed out replaced with citizens a reference to the movie 'The Departed'
](https://cdn.jsdelivr.net/gh/allinbits/gnoserve@metamodel/static/citizens.svg)

Models can represent anything, from simple workflows to complex systems like economic models, supply chains, or even entire blockchain protocols.
This library is designed to be extensible, allowing users to bind model objects to other gno objects, enabling rich interactions and dynamic behaviors.

The goal is to provide a powerful yet intuitive framework for modeling dynamic systems, enabling users to explore
the behavior of their models, validate logic, and export them for execution or further analysis.

Submit your models to a public index to become a model citizen and share your work with the community!`

func renderIndex(path string) string {
	var sb strings.Builder
	sb.WriteString("# Metamodel000 Index\n\n")
	sb.WriteString("This is a public registry of metamodels.\n\n")
	sb.WriteString("### What is a Metamodel?\n\n")
	sb.WriteString("A _metamodel_ is a framework for modeling dynamic systems using places, transitions, and arrows, inspired by Petri nets.\n\n")
	sb.WriteString("Models are defined as a set of _$objects_, each with a **unique identity** (e.g. $eth, $btc, $coffee_beans )\n\n")
	sb.WriteString("Each _$object_ is defined by its behavior **in all contexts**.\n\n")
	sb.WriteString("### Documentation\n\n")
	sb.WriteString("  - [Metamodel Codex](/r/metamodel000:metamodel-codex) An introduction to modeling.\n")
	sb.WriteString("    - [Review of models using blockchain terminology](/r/metamodel000:metamodel-codex#petri-net-vs-blockchain-analogy)\n")
	sb.WriteString("  - [Metamodel Simulation](/r/metamodel000:metamodel-simulation) using continuous Petri nets.\n\n")
	//sb.WriteString(mm.SubmitButton("Become a Model Citizen", "/r/metamodel000:metamodel-codex#become-a-model-citizen", 16, 255))
	//sb.WriteString(citizens)
	return sb.String()
}

func Render(path string) string {
	return registry.Render(path, renderIndex)
}
