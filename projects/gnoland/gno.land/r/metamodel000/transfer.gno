package metamodel

import (
    "std"
    "strconv"
	mm "gno.land/p/metamodel000"
)
// TODO: make this form populate from URL http://127.0.0.1:8888/r/metamodel000?amount=3&toAddress=g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz

var transferForm = `
<gno-form>
    <gno-input name="amount" placeholder="3" />
    <gno-input name="toAddress" placeholder="g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz" />
</gno-form>
`


func init() {
    exampleModel := transfer("g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz", "PAY2ADDR", 3)
	register("transfer", func(_ string) string {
		return transferForm + exampleModel.ToMarkdown()
	})
}

// transfer creates a model to transfer tokens from a wallet to a specified address.
func transfer(toAddress string, action string, multiple int64) *mm.Model {
	return &mm.Model{
		Places: map[string]mm.Place{
			"$wallet": {Offset: 0, Initial: mm.T(9), Capacity: mm.T(0), X: 20, Y: 50},
			toAddress: {Offset: 0, Initial: mm.T(0), Capacity: mm.T(0), X: 270, Y: 50},
		},
		Transitions: map[string]mm.Transition{
			action: {X: 150, Y: 50},
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
    std.Emit("PAY2ADDR", "toAddress", toAddress, "amount", strconv.Itoa(int(amount)))
}