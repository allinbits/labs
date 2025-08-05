package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var qwertyNotes string = `
This is a QWERTY keyboard layout model.

Though not overly useful in itself, it serves as a demonstration that inputs without any place constraints are identical to pure transition models.

Thus, we can control a re-usable model vocabulary that can be built upon by appending arrows and places to the model.
`
var (
    externalLink = `[![pflow](https://pflow.dev/img/zb2rhoVtN4MTsEuAEL6eMDog85mvLx91jG5LTnnDZ6fxxqVRb.svg)](https://pflow.dev/p/zb2rhoVtN4MTsEuAEL6eMDog85mvLx91jG5LTnnDZ6fxxqVRb/)`
)


func init() {
	keyboard := qwertyModel()
	keyboard.Binding = func(_ string) string {
		return qwertyNotes + keyboard.ToMarkdown() + externalLink
	}
    register("Keyboard", keyboard)
}

func qwertyModel() *mm.Model {
	transitions := map[string]mm.Transition{
		"A":        {X: 125, Y: 160},
		"B":        {X: 350, Y: 220},
		"C":        {X: 250, Y: 220},
		"D":        {X: 225, Y: 160},
		"E":        {X: 200, Y: 100},
		"Enter":    {X: 580, Y: 160},
		"F":        {X: 275, Y: 160},
		"G":        {X: 325, Y: 160},
		"H":        {X: 375, Y: 160},
		"I":        {X: 450, Y: 100},
		"J":        {X: 425, Y: 160},
		"K":        {X: 475, Y: 160},
		"L":        {X: 525, Y: 160},
		"M":        {X: 450, Y: 220},
		"N":        {X: 400, Y: 220},
		"O":        {X: 500, Y: 100},
		"P":        {X: 550, Y: 100},
		"Q":        {X: 100, Y: 100},
		"R":        {X: 250, Y: 100},
		"S":        {X: 175, Y: 160},
		"Spacebar": {X: 300, Y: 280},
		"T":        {X: 300, Y: 100},
		"U":        {X: 400, Y: 100},
		"V":        {X: 300, Y: 220},
		"W":        {X: 150, Y: 100},
		"X":        {X: 200, Y: 220},
		"Y":        {X: 350, Y: 100},
		"Z":        {X: 150, Y: 220},
	}

	return &mm.Model{
		Places:      map[string]mm.Place{}, // No places defined in the model
		Transitions: transitions,
		Arrows:      []mm.Arrow{}, // No arcs defined in the model
	}
}
