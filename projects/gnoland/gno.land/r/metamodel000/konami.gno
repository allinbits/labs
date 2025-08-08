package metamodel

import mm "gno.land/p/metamodel000"

var konamiCodeDescription = `
This is a model of the Konami Code, a famous cheat code used in many video games
and pop culture references. The code is typically entered using a game controller and consists of a sequence of directional inputs and button presses.

`

func init() {
	model := konamiCodeModel()
	model.Binding = func(_ string) string {
		return konamiCodeDescription + model.ToMarkdown()
	}
	keywords := []string{"cheat", "games", "nintendo"}
	register("Konami Code", model, keywords...)
}

func konamiCodeModel() *mm.Model {
	places := map[string]mm.Place{
		"up.up":       {Offset: 0, Initial: mm.T(2), Capacity: mm.T(2), X: 160, Y: 150},
		"down.down":   {Offset: 1, Initial: mm.T(2), Capacity: mm.T(2), X: 80, Y: 230},
		"two.lefts":   {Offset: 2, Initial: mm.T(2), Capacity: mm.T(2), X: 80, Y: 70},
		"then.right":  {Offset: 3, Capacity: mm.T(1), X: 240, Y: 230},
		"two.rights":  {Offset: 4, X: 240, Y: 70},
		"then.A":      {Offset: 5, Capacity: mm.T(1), X: 480, Y: 70},
		"then.Select": {Offset: 6, Capacity: mm.T(1), X: 320, Y: 230},
		"then.Start":  {Offset: 7, Capacity: mm.T(1), X: 400, Y: 230},
	}

	transitions := map[string]mm.Transition{
		"up":     {X: 160, Y: 70},
		"down":   {X: 160, Y: 230},
		"left":   {X: 80, Y: 150},
		"right":  {X: 240, Y: 150},
		"select": {X: 320, Y: 150},
		"start":  {X: 400, Y: 150},
		"b":      {X: 480, Y: 150},
		"a":      {X: 560, Y: 150},
	}

	arrows := []mm.Arrow{
		{Source: "up.up", Target: "up"},
		{Source: "up.up", Target: "down", Inhibit: true},
		{Source: "down.down", Target: "down"},
		{Source: "down.down", Target: "left", Inhibit: true},
		{Source: "two.lefts", Target: "left"},
		{Source: "then.right", Target: "right"},
		{Source: "left", Target: "then.right"},
		{Source: "two.rights", Target: "b", Weight: mm.T(2)},
		{Source: "right", Target: "two.rights"},
		{Source: "then.A", Target: "a"},
		{Source: "b", Target: "then.A"},
		{Source: "then.Select", Target: "select"},
		{Source: "a", Target: "then.Select"},
		{Source: "then.Start", Target: "start"},
		{Source: "select", Target: "then.Start"},
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}
