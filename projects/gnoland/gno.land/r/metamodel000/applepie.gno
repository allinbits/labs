package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var applePieDescription = `
“If you wish to make an apple pie from scratch, you must first invent the universe.” — Carl Sagan

This model captures the essential stages of baking an apple pie, modeling ingredients, tools,
and preparation steps as a distributed system.
Each transition represents a key process — from making dough and filling,
to baking — offering a structured, composable recipe you can simulate, visualize, and even extend.
`

func init() {
	applePieModel := applePie()
	applePieModel.Binding = func(_ string) string {
		return applePieDescription + applePieModel.ToMarkdown()
	}
	register("Apple Pie", applePieModel)
}

func applePie() *mm.Model {
	places := map[string]mm.Place{
		"Flour":      {Offset: 0, Initial: mm.T(1), Capacity: mm.T(1), X: 100, Y: 100},
		"Butter":     {Offset: 1, Initial: mm.T(1), Capacity: mm.T(1), X: 100, Y: 160},
		"Water":      {Offset: 2, Initial: mm.T(1), Capacity: mm.T(1), X: 100, Y: 220},
		"Apples":     {Offset: 3, Initial: mm.T(1), Capacity: mm.T(1), X: 100, Y: 300},
		"Sugar":      {Offset: 4, Initial: mm.T(1), Capacity: mm.T(1), X: 100, Y: 360},
		"Cinnamon":   {Offset: 5, Initial: mm.T(1), Capacity: mm.T(1), X: 100, Y: 420},
		"Oven":       {Offset: 6, Initial: mm.T(1), Capacity: mm.T(1), X: 100, Y: 500},
		"Dough":      {Offset: 7, Initial: mm.T(0), Capacity: mm.T(1), X: 300, Y: 160},
		"Filling":    {Offset: 8, Initial: mm.T(0), Capacity: mm.T(1), X: 300, Y: 360},
		"UnbakedPie": {Offset: 9, Initial: mm.T(0), Capacity: mm.T(1), X: 500, Y: 260},
		"BakedPie":   {Offset: 10, Initial: mm.T(0), Capacity: mm.T(1), X: 700, Y: 260},
	}

	transitions := map[string]mm.Transition{
		"MakeDough":   {Label: "Make Dough", Offset: 0, X: 200, Y: 160},
		"MakeFilling": {Label: "Make Filling", Offset: 0, X: 200, Y: 360},
		"AssemblePie": {Label: "Assemble Pie", Offset: 0, X: 400, Y: 260},
		"BakePie":     {Label: "Bake Pie", Offset: 0, X: 600, Y: 260},
	}

	arrows := []mm.Arrow{
		{Source: "Flour", Target: "MakeDough"},
		{Source: "Butter", Target: "MakeDough"},
		{Source: "Water", Target: "MakeDough"},
		{Source: "MakeDough", Target: "Dough"},
		{Source: "Apples", Target: "MakeFilling"},
		{Source: "Sugar", Target: "MakeFilling"},
		{Source: "Cinnamon", Target: "MakeFilling"},
		{Source: "MakeFilling", Target: "Filling"},
		{Source: "Dough", Target: "AssemblePie"},
		{Source: "Filling", Target: "AssemblePie"},
		{Source: "AssemblePie", Target: "UnbakedPie"},
		{Source: "UnbakedPie", Target: "BakePie"},
		{Source: "Oven", Target: "BakePie"},
		{Source: "BakePie", Target: "BakedPie"},
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}
