package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var knapsackDescription = `
This is a simple Petri net model of the 0/1 Knapsack problem.

Places:
- item0, item1, item2, item3: Each item can be selected once.
- weight: Accumulated weight of selected items.
- value: Accumulated value of selected items.
- capacity: Remaining knapsack capacity.

Transitions:
- txn0–txn3: Select item0–item3, updating weight, value, and capacity.

Notes:
- Each transition represents picking an item, consuming its token, adding its weight and value, and reducing capacity.
- The model does not enforce optimality, only the process of selection under capacity constraints.

📓 Try notebook: [Knapsack (Petri.jl)](https://gist.github.com/stackdump/7351cba2958626fe6196b566069ccb1e)

`

func init() {
	ksModel := knapsack()
	ksModel.Binding = func(_ string) string {
		return knapsackDescription + ksModel.ToMarkdown()
	}
	keywords := []string{
		"knapsack", "petri-net", "optimization", "combinatorial", "capacity", "value", "weight",
	}
	register("Knapsack", ksModel, keywords...)
}

func knapsack() *mm.Model {
	places := map[string]mm.Place{
		"item0":    {Offset: 0, Initial: mm.T(1), X: 140, Y: 191},
		"item1":    {Offset: 1, Initial: mm.T(1), X: 145, Y: 316},
		"item2":    {Offset: 2, Initial: mm.T(1), X: 140, Y: 451},
		"item3":    {Offset: 3, Initial: mm.T(1), X: 145, Y: 569},
		"weight":   {Offset: 4, Initial: mm.T(0), X: 550, Y: 514},
		"value":    {Offset: 5, Initial: mm.T(0), X: 665, Y: 190},
		"capacity": {Offset: 6, Initial: mm.T(15), X: 476, Y: 569},
	}

	transitions := map[string]mm.Transition{
		"txn0": {Label: "txn0", Offset: 0, X: 268, Y: 190},
		"txn1": {Label: "txn1", Offset: 1, X: 270, Y: 318},
		"txn2": {Label: "txn2", Offset: 2, X: 268, Y: 451},
		"txn3": {Label: "txn3", Offset: 3, X: 269, Y: 572},
	}

	arrows := []mm.Arrow{
		// Item 0
		{Source: "item0", Target: "txn0"},
		{Source: "capacity", Target: "txn0", Weight: mm.T(2)},
		{Source: "txn0", Target: "weight", Weight: mm.T(2)},
		{Source: "txn0", Target: "value", Weight: mm.T(10)},

		// Item 1
		{Source: "item1", Target: "txn1"},
		{Source: "capacity", Target: "txn1", Weight: mm.T(4)},
		{Source: "txn1", Target: "weight", Weight: mm.T(4)},
		{Source: "txn1", Target: "value", Weight: mm.T(10)},

		// Item 2
		{Source: "item2", Target: "txn2"},
		{Source: "capacity", Target: "txn2", Weight: mm.T(6)},
		{Source: "txn2", Target: "weight", Weight: mm.T(6)},
		{Source: "txn2", Target: "value", Weight: mm.T(12)},

		// Item 3
		{Source: "item3", Target: "txn3"},
		{Source: "capacity", Target: "txn3", Weight: mm.T(9)},
		{Source: "txn3", Target: "weight", Weight: mm.T(9)},
		{Source: "txn3", Target: "value", Weight: mm.T(18)},
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}