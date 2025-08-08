package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var philosophersIntro = `
The **Dining Philosophers** Petri net models concurrent resource sharing and deadlock.
Each philosopher alternates between thinking and eating, requiring two chopsticks (shared resources) to eat.

This model visualizes the classic concurrency problem and its solutions.
`

var philosophersDescription = `
### Model Structure

- **Places**: Represent chopsticks and philosopher states (left/right, thinking).
- **Transitions**: Represent philosophers starting to eat or think.
- **Arrows**: Model the acquisition and release of chopsticks.

This model can be simulated to explore deadlock, resource contention, and concurrency patterns.
`

func init() {
	model := philosophersModel()
	model.Binding = func(_ string) string {
		return philosophersIntro +
			"![Dining Philosophers](https://cdn.jsdelivr.net/gh/allinbits/gnoserve@metamodel/static/philosophers.svg)\n" +
			philosophersDescription +
			model.ToMarkdown()
	}
	register("Dining Philosophers", model)
}

func philosophersModel() *mm.Model {
	places := map[string]mm.Place{
		"chopstick0": {Offset: 0, X: 403, Y: 340},
		"chopstick1": {Offset: 1, Initial: mm.T(1), X: 534, Y: 345},
		"chopstick2": {Offset: 2, X: 358, Y: 467},
		"chopstick3": {Offset: 3, Initial: mm.T(1), X: 547, Y: 461},
		"chopstick4": {Offset: 4, Initial: mm.T(1), X: 451, Y: 536},
		"0right":     {Offset: 5, X: 415, Y: 181},
		"0left":      {Offset: 6, X: 545, Y: 177},
		"1right":     {Offset: 7, X: 719, Y: 288},
		"1left":      {Offset: 8, X: 769, Y: 404},
		"2left":      {Offset: 9, X: 686, Y: 584},
		"2right":     {Offset: 10, X: 594, Y: 678},
		"3left":      {Offset: 11, X: 315, Y: 679},
		"3right":     {Offset: 12, X: 216, Y: 608},
		"4right":     {Offset: 13, Initial: mm.T(1), X: 148, Y: 397},
		"4left":      {Offset: 14, Initial: mm.T(1), X: 183, Y: 289},
	}
	transitions := map[string]mm.Transition{
		"0think": {X: 478, Y: 106},
		"0eat":   {X: 473, Y: 247},
		"1eat":   {X: 654, Y: 396},
		"2eat":   {X: 574, Y: 573},
		"3eat":   {X: 333, Y: 556},
		"4eat":   {X: 267, Y: 370},
		"1think": {X: 842, Y: 304},
		"4think": {X: 72, Y: 314},
		"3think": {X: 200, Y: 726},
		"2think": {X: 740, Y: 699},
	}
	arrows := []mm.Arrow{
		{Source: "chopstick0", Target: "0eat"},
		{Source: "chopstick1", Target: "0eat"},
		{Source: "chopstick0", Target: "4eat"},
		{Source: "chopstick2", Target: "4eat"},
		{Source: "chopstick1", Target: "1eat"},
		{Source: "chopstick3", Target: "1eat"},
		{Source: "chopstick2", Target: "3eat"},
		{Source: "chopstick4", Target: "3eat"},
		{Source: "chopstick4", Target: "2eat"},
		{Source: "chopstick3", Target: "2eat"},
		{Source: "0eat", Target: "0right"},
		{Source: "0eat", Target: "0left"},
		{Source: "1eat", Target: "1right"},
		{Source: "1eat", Target: "1left"},
		{Source: "2eat", Target: "2left"},
		{Source: "2eat", Target: "2right"},
		{Source: "3eat", Target: "3right"},
		{Source: "3eat", Target: "3left"},
		{Source: "4eat", Target: "4right"},
		{Source: "4eat", Target: "4left"},
		{Source: "0right", Target: "0think"},
		{Source: "0left", Target: "0think"},
		{Source: "1right", Target: "1think"},
		{Source: "1left", Target: "1think"},
		{Source: "2left", Target: "2think"},
		{Source: "2right", Target: "2think"},
		{Source: "4left", Target: "4think"},
		{Source: "4right", Target: "4think"},
		{Source: "3right", Target: "3think"},
		{Source: "3left", Target: "3think"},
		{Source: "4think", Target: "chopstick0"},
		{Source: "4think", Target: "chopstick2"},
		{Source: "0think", Target: "chopstick0"},
		{Source: "0think", Target: "chopstick1"},
		{Source: "1think", Target: "chopstick1"},
		{Source: "1think", Target: "chopstick3"},
		{Source: "2think", Target: "chopstick3"},
		{Source: "2think", Target: "chopstick4"},
		{Source: "3think", Target: "chopstick2"},
		{Source: "3think", Target: "chopstick4"},
	}
	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}
