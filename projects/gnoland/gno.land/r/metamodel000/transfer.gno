package metamodel

import (
    "std"
	mm "gno.land/p/metamodel000"
)

func init() {
	register("transfer", func(_ string) string {
		return transfer("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz", "PAY2ADDR", 3).ToMarkdown()
	})
}

// transfer creates a model to transfer tokens from a wallet to a specified address.
func transfer(toAddress string, action string, multiple int64) *mm.Model {
	return &mm.Model{
		Places: map[string]mm.Place{
			"$wallet": {Offset: 0, Initial: mm.T(9), Capacity: mm.T(0), X: 20, Y: 100},
			toAddress: {Offset: 0, Initial: mm.T(0), Capacity: mm.T(0), X: 270, Y: 100},
		},
		Transitions: map[string]mm.Transition{
			action: {X: 150, Y: 100},
		},
		Arrows: []mm.Arrow{
			{Source: "$wallet", Target: action, Weight: mm.T(multiple)},
			{Source: action, Target: toAddress, Weight: mm.T(multiple)},
		},
	}
}

// Transfer simulates a transfer of tokens from the current realm's wallet to a specified address.
func Transfer(cur realm, toAddress string, amount int64) {
    m := transfer(toAddress, "PAY2ADDR", amount)
    _ = m
    // m.Execute(cur) // FIXME - execute for the current realm
    std.Emit("PAY2ADDR", "toAddress", toAddress, "amount", amount)
}