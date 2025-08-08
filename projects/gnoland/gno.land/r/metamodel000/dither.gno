package metamodel

import (
	"std"

	mm "gno.land/p/metamodel000"
)

// Description and form for the dither model
var ditherDescription = `
This model sends a payment of 1 token from the account to a specified address.
The Dither protocol allows for messages to be sent in the memo field of the transaction, enabling simple communication alongside the transfer of value.

Spam is controlled by throttling amount sent vs quantity of messages sent.
`

var ditherForm = `
<gno-form>
    <gno-input name="msg" placeholder="message" />
    <gno-input name="toAddress" placeholder="g1..." />
</gno-form>
`

func init() {
	exampleModel := dither("message{}", "g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz")
	exampleModel.Binding = func(_ string) string {
		return ditherDescription + ditherForm + exampleModel.ToMarkdown()
	}
	register("dither", exampleModel)
}

// dither creates a model that always sends 1 token from $wallet to address
func dither(msg string, toAddress string) *mm.Model {
	return &mm.Model{
		Places: map[string]mm.Place{
			"$account": {Offset: 0, Initial: mm.T(1), Capacity: mm.T(0), X: 30, Y: 50},
			toAddress:  {Offset: 1, Initial: mm.T(0), Capacity: mm.T(0), X: 280, Y: 50},
		},
		Transitions: map[string]mm.Transition{
			msg: {X: 160, Y: 50},
		},
		Arrows: []mm.Arrow{
			{Source: "$account", Target: msg},
			{Source: msg, Target: toAddress},
		},
	}
}

func exampleDither(cur realm, msg string, toAddress string) {
	m := dither(msg, toAddress)
	_ = m // call m.Execute() to verify model action
	// in reality users send messages directly using the memo field
	std.Emit("DITHER", "msg", msg, "toAddress", toAddress)
}
