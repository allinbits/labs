package metamodel

import mm "gno.land/p/metamodel000"

var ticTacToeDescription = `
This Petri net models the flow of a Tic Tac Toe game using places and transitions to represent board states and player actions. The structure supports two distinct but compatible interpretations:

`

var ticTacToeNotes = `
This Petri net models the flow of a Tic Tac Toe game using places and transitions to represent board states and player actions. The structure supports two distinct but compatible interpretations:

#### Game Board View (Compositional Model of State)
Each place corresponds to a position on the 3×3 Tic Tac Toe board. For example:

"00" is the top-left corner,

"11" is the center,

"22" is the bottom-right.

The token at a place indicates whether that square is available or has been marked.

Two types of transitions represent player actions:

"X00": places an X in position "00",

"O00": places an O in position "00".

Each transition consumes the token from "00" (indicating it's unoccupied) and places a token in "X00" or "O00", marking that the square is now taken.

#### Rewriting System View (Symbolic State Rewriting)
This net can also be viewed as a symbolic rewriting system:

The place "00" represents the symbol "00" (an unmarked cell).

The transitions "X00" and "O00" represent rewrite rules:

"00" → "X00"   or   "00" → "O00"
depending on whose turn it is.

Additionally, a control place called "next" tracks the current player’s turn:

When "next" holds an "X" token, only transitions to "X##" are enabled.

When it holds an "O" token, only "O##" transitions are enabled.

Each transition also updates "next" to alternate turns:

next = X → O
next = O → X

This dual lens allows the model to serve both as a game simulator and as a general symbolic rewriting engine.

The Petri net’s native concurrency also reveals how multiple board positions can be independently available, but player turns enforce a strict global alternation constraint.


#### Continuous Model Interpretation (Expert System Mode)
In addition to its discrete gameplay semantics, this Petri net also supports a continuous interpretation using weighted rates and token flows.

By assigning firing rates to transitions and interpreting token values as real-valued densities (rather than integer counts), the model behaves like a continuous-time system. In this formulation, tokens represent probabilities distributed over possible game states.

For example, if transitions like "X00" or "O11" are assigned rates proportional to their strategic value, the net evolves over time into a probabilistic expert system: each place accumulates a token density corresponding to the likelihood of that board position being selected next under optimal play.

This expert system view is implemented and visualized in the following notebook:

📓 [Tic Tac Toe Expert System (Petri.jl)](https://gist.github.com/stackdump/06e7ccc96dd08b478b0da781a88c8d7a#file-tic-tac-toe-expert-system-ipynb)

This augmented model appends win-detection logic, allowing it to recognize winning states and update the "next" place accordingly. It also includes a continuous simulation mode that runs the game dynamics over time, showing how strategies evolve.
[![pflow](https://pflow.dev/img/zb2rhosFBUreeqMAKLc5XW7aSy6hCgAJJrq93i6B2vRJS3VhN.svg)](https://pflow.dev/p/zb2rhosFBUreeqMAKLc5XW7aSy6hCgAJJrq93i6B2vRJS3VhN/)

It uses Petri.jl to simulate the continuous dynamics and solve the resulting ODEs, giving insight into how the strategy space unfolds over time. This interpretation provides a bridge between symbolic gameplay and fluid probabilistic reasoning.

### Try the interactive demo at pflow.xyz
[![pflow](https://pflow.dev/img/zb2rhfp7ZoggzxF7orkkjEU6Emq6N7VB9pATsi9vLdHSKy1t7.svg)](https://pflow.dev/p/zb2rhfp7ZoggzxF7orkkjEU6Emq6N7VB9pATsi9vLdHSKy1t7/)


`

func init() {
	model := ticTacToe()
	model.Binding = func(_ string) string {
		return ticTacToeDescription + model.ToMarkdown() + ticTacToeNotes
	}
	keywords := []string{"game", "rewriting", "expert-system"}
	register("TicTacToe", model, keywords...)
}

func ticTacToe() *mm.Model {
	places := map[string]mm.Place{
		"10":   {Offset: 0, Initial: mm.T(1), Capacity: mm.T(1), X: 60, Y: 150},
		"11":   {Offset: 1, Initial: mm.T(1), Capacity: mm.T(1), X: 140, Y: 150},
		"12":   {Offset: 2, Initial: mm.T(1), Capacity: mm.T(1), X: 220, Y: 150},
		"20":   {Offset: 3, Initial: mm.T(1), Capacity: mm.T(1), X: 60, Y: 230},
		"21":   {Offset: 4, Initial: mm.T(1), Capacity: mm.T(1), X: 140, Y: 230},
		"22":   {Offset: 5, Initial: mm.T(1), Capacity: mm.T(1), X: 220, Y: 230},
		"00":   {Offset: 6, Initial: mm.T(1), Capacity: mm.T(1), X: 60, Y: 70},
		"01":   {Offset: 7, Initial: mm.T(1), Capacity: mm.T(1), X: 140, Y: 70},
		"02":   {Offset: 8, Initial: mm.T(1), Capacity: mm.T(1), X: 220, Y: 70},
		"next": {Offset: 9, Capacity: mm.T(1), X: 460, Y: 470},
	}

	transitions := map[string]mm.Transition{
		"X00": {X: 380, Y: 70},
		"X01": {X: 460, Y: 70},
		"X02": {X: 540, Y: 70},
		"X10": {X: 380, Y: 150},
		"X11": {X: 460, Y: 150},
		"X12": {X: 540, Y: 150},
		"X20": {X: 380, Y: 230},
		"X21": {X: 460, Y: 230},
		"X22": {X: 540, Y: 230},
		"O00": {X: 60, Y: 390},
		"O01": {X: 140, Y: 390},
		"O02": {X: 220, Y: 390},
		"O10": {X: 60, Y: 470},
		"O11": {X: 140, Y: 470},
		"O12": {X: 220, Y: 470},
		"O20": {X: 60, Y: 550},
		"O21": {X: 140, Y: 550},
		"O22": {X: 220, Y: 550},
	}

	arrows := []mm.Arrow{
		{Source: "00", Target: "X00"},
		{Source: "X00", Target: "next"},
		{Source: "01", Target: "X01"},
		{Source: "X01", Target: "next"},
		{Source: "02", Target: "X02"},
		{Source: "X02", Target: "next"},
		{Source: "10", Target: "X10"},
		{Source: "X10", Target: "next"},
		{Source: "11", Target: "X11"},
		{Source: "X11", Target: "next"},
		{Source: "12", Target: "X12"},
		{Source: "X12", Target: "next"},
		{Source: "20", Target: "X20"},
		{Source: "X20", Target: "next"},
		{Source: "21", Target: "X21"},
		{Source: "X21", Target: "next"},
		{Source: "22", Target: "X22"},
		{Source: "X22", Target: "next"},
		{Source: "00", Target: "O00"},
		{Source: "next", Target: "O00"},
		{Source: "01", Target: "O01"},
		{Source: "next", Target: "O01"},
		{Source: "02", Target: "O02"},
		{Source: "next", Target: "O02"},
		{Source: "10", Target: "O10"},
		{Source: "next", Target: "O10"},
		{Source: "11", Target: "O11"},
		{Source: "next", Target: "O11"},
		{Source: "12", Target: "O12"},
		{Source: "next", Target: "O12"},
		{Source: "20", Target: "O20"},
		{Source: "next", Target: "O20"},
		{Source: "21", Target: "O21"},
		{Source: "next", Target: "O21"},
		{Source: "22", Target: "O22"},
		{Source: "next", Target: "O22"},
	}

	return mm.New(places, transitions, arrows)
}
