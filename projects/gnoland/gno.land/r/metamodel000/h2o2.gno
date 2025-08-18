package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var h2o2CatalystDescription = `
This is a model of the catalyzed decomposition of hydrogen peroxide:

2 H₂O₂ + Catalyst → [Complex] → 2 H₂O + O₂ + Catalyst

The catalyst participates in the reaction but is regenerated in the process,
demonstrating how catalysts speed up reactions without being consumed.
`

func init() {
	model := h2o2Catalyst()
	model.Binding = func(_ string) string {
		return h2o2CatalystDescription + model.ToMarkdown()
	}
	keywords := []string{"hydrogen-peroxide", "catalyst", "h2o2", "h2o", "o2", "mnO2"}
	register("Catalyzed H2O2 Decomposition", model, keywords...)
}

func h2o2Catalyst() *mm.Model {
	places := map[string]mm.Place{
		"H2O2":    {Offset: 0, Initial: mm.T(10), Capacity: mm.T(0), X: 50, Y: 100},
		"Cat":     {Offset: 1, Initial: mm.T(1), Capacity: mm.T(0), X: 50, Y: 180},
		"Complex": {Offset: 2, Initial: mm.T(0), Capacity: mm.T(0), X: 250, Y: 140},
		"H2O":     {Offset: 3, Initial: mm.T(0), Capacity: mm.T(0), X: 450, Y: 100},
		"O2":      {Offset: 4, Initial: mm.T(0), Capacity: mm.T(0), X: 450, Y: 180},
	}

	transitions := map[string]mm.Transition{
		"Adsorb":    {Label: "Adsorb", Offset: 0, X: 150, Y: 140},
		"Decompose": {Label: "Decompose", Offset: 1, X: 350, Y: 140},
	}

	arrows := []mm.Arrow{
		// Adsorption step
		{Source: "H2O2", Target: "Adsorb"},
		{Source: "H2O2", Target: "Adsorb"}, // 2 H2O2 molecules
		{Source: "Cat", Target: "Adsorb"},
		{Source: "Adsorb", Target: "Complex"},

		// Decomposition step
		{Source: "Complex", Target: "Decompose"},
		{Source: "Decompose", Target: "Cat"},
		{Source: "Decompose", Target: "H2O"},
		{Source: "Decompose", Target: "H2O"}, // 2 H2O molecules
		{Source: "Decompose", Target: "O2"},
	}

	return mm.New(places, transitions, arrows)
}
