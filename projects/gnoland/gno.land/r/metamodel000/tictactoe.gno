package metamodel

import mm "gno.land/p/metamodel000"

func init() {
	model := ticTacToe()
	register("TicTacToe", func(_ string) string {
		return model.ToMarkdown()
	})
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
		"000": {X: 60, Y: 390},
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
		{Source: "00", Target: "000"},
		{Source: "next", Target: "000"},
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

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}
