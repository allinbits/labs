package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var h2oDescription = `
This is a model of the combustion of hydrogen and oxygen to form water:

2 H₂ + O₂ + Energy → 2 H₂O
`

func init() {
	h2oModel := h2o()
	h2oModel.Binding = func(_ string) string {
		return h2oDescription + h2oModel.ToMarkdown()
	}
	keywords := []string{"hydrogen", "oxygen", "water", "combustion", "h2", "o2", "h2o"}
	register("H2O Combustion", h2oModel, keywords...)
}

func h2o() *mm.Model {
	places := map[string]mm.Place{
		"H2":     {Offset: 0, Initial: mm.T(2), Capacity: mm.T(2), X: 50, Y: 80},
		"O2":     {Offset: 1, Initial: mm.T(1), Capacity: mm.T(1), X: 50, Y: 140},
		"Energy": {Offset: 2, Initial: mm.T(1), Capacity: mm.T(1), X: 50, Y: 200},
		"H2O":    {Offset: 3, Initial: mm.T(0), Capacity: mm.T(2), X: 300, Y: 120},
	}

	transitions := map[string]mm.Transition{
		"Combustion": {Label: "Combustion", Offset: 0, X: 180, Y: 120},
	}

	arrows := []mm.Arrow{
		{Source: "H2", Target: "Combustion"},
		{Source: "H2", Target: "Combustion"}, // 2 H2 molecules
		{Source: "O2", Target: "Combustion"},
		{Source: "Energy", Target: "Combustion"},
		{Source: "Combustion", Target: "H2O"},
		{Source: "Combustion", Target: "H2O"}, // 2 H2O molecules
	}

	return mm.New(places, transitions, arrows)
}