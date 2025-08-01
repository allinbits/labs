package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var coffeeShopDescription = `
This is a model of a coffee shop process, which includes the following steps:

`

func init() {
	coffeeShopModel := coffeeShop()
	coffeeShopModel.Binding = func(_ string) string {
		return coffeeShopDescription + coffeeShopModel.ToMarkdown()
	}
	register("coffeeShop", coffeeShopModel)
}

func coffeeShop() *mm.Model {
	places := map[string]mm.Place{
		"Water":        {Offset: 0, Initial: mm.T(1), Capacity: mm.T(1), X: 35, Y: 66},
		"BoiledWater":  {Offset: 1, Initial: mm.T(0), Capacity: mm.T(1), X: 293, Y: 93},
		"CoffeeBeans":  {Offset: 2, Initial: mm.T(1), Capacity: mm.T(1), X: 35, Y: 126},
		"GroundCoffee": {Offset: 3, Initial: mm.T(0), Capacity: mm.T(1), X: 296, Y: 153},
		"Filter":       {Offset: 4, Initial: mm.T(1), Capacity: mm.T(1), X: 35, Y: 190},
		"CoffeeInPot":  {Offset: 5, Initial: mm.T(0), Capacity: mm.T(1), X: 300, Y: 222},
		"Pending":      {Offset: 6, Initial: mm.T(1), Capacity: mm.T(1), X: 518, Y: 68},
		"Sent":         {Offset: 7, Initial: mm.T(0), Capacity: mm.T(1), X: 524, Y: 158},
		"Payment":      {Offset: 8, Initial: mm.T(0), Capacity: mm.T(1), X: 528, Y: 246},
		"Cup":          {Offset: 9, Initial: mm.T(1), Capacity: mm.T(1), X: 35, Y: 249},
	}

	transitions := map[string]mm.Transition{
		"BoilWater":  {Label: "Boil Water", Offset: 0, X: 184, Y: 67},
		"BrewCoffee": {Label: "Brew Coffee", Offset: 0, X: 183, Y: 191},
		"Credit":     {Label: "Credit Payment", Offset: 0, X: 393, Y: 188},
		"GrindBeans": {Label: "Grind Beans", Offset: 0, X: 180, Y: 128},
		"PourCoffee": {Label: "Pour Coffee", Offset: 0, X: 183, Y: 252},
		"Send":       {Label: "Send Order", Offset: 0, X: 392, Y: 111},
	}

	arrows := []mm.Arrow{
		{Source: "Water", Target: "BoilWater"},
		{Source: "BoilWater", Target: "BoiledWater"},
		{Source: "CoffeeBeans", Target: "GrindBeans"},
		{Source: "GrindBeans", Target: "GroundCoffee"},
		{Source: "BoiledWater", Target: "BrewCoffee"},
		{Source: "GroundCoffee", Target: "BrewCoffee"},
		{Source: "Filter", Target: "BrewCoffee"},
		{Source: "BrewCoffee", Target: "CoffeeInPot"},
		{Source: "CoffeeInPot", Target: "PourCoffee"},
		{Source: "Cup", Target: "PourCoffee"},
		{Source: "Pending", Target: "Send"},
		{Source: "Send", Target: "Sent"},
		{Source: "Sent", Target: "Credit"},
		{Source: "Credit", Target: "Payment"},
		{Source: "PourCoffee", Target: "Payment", Inhibit: true},
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}
