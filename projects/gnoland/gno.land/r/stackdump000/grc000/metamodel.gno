package grc000

import (
	mm "gno.land/p/metamodel000"
)

func GRC000_Wallet() *mm.Model {
	return mm.New(map[string]mm.Place{
		"$wallet": {Offset: 0, Initial: mm.T(1), Capacity: mm.T(0), X: 60, Y: 60},
	})
}

func GRC000_Transfer() *mm.Model {
	return mm.New(
		GRC000_Wallet(),
		map[string]mm.Place{
			"$recipient": {Offset: 1, Initial: mm.T(0), X: 240, Y: 60}, // recipient port
		},
		map[string]mm.Transition{
			"transfer": {X: 150, Y: 60},
		},
		[]mm.Arrow{
			{Source: "$wallet", Target: "transfer", Weight: mm.T(1)},
			{Source: "transfer", Target: "$recipient", Weight: mm.T(1)},
		},
	)
}

func GRC000_MintBurn() *mm.Model {
	return mm.New(
		GRC000_Wallet(),
		map[string]mm.Place{
			"$minter": {Offset: 0, Initial: mm.T(1), X: 60, Y: 140},
		},
		map[string]mm.Transition{
			"mint": {X: 150, Y: 140},
			"burn": {X: 150, Y: 200},
		},
		[]mm.Arrow{
			{Source: "$minter", Target: "mint", Weight: mm.T(1)},
			{Source: "mint", Target: "$wallet", Weight: mm.T(1)},
			{Source: "$wallet", Target: "burn", Weight: mm.T(1)},
		},
	)
}

func GRC000_Token() *mm.Model {
	return mm.New(
		GRC000_Wallet(),
		GRC000_Transfer(),
		GRC000_MintBurn(),
		map[string]interface{}{"version": "v0"}, // RenderOpts
	)
}
