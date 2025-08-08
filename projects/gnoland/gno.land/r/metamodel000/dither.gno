package metamodel

import (
	"std"

	mm "gno.land/p/metamodel000"
)

// Description and form for the dither model
var ditherDescription = `
One would think there is only a semantic difference between sending a message and sending a payment with a message, but in fact there is a big difference in the way spam is controlled.

This model sends a payment from the account to a specified address.
The Dither protocol allows for messages to be sent in the memo field of the transaction, enabling simple communication alongside the transfer of value.

Spam is controlled by throttling ratio of sent amount vs quantity of messages sent.

NOTE: That this is a censorship resistant form of throttling,
as a user only filters messages in the UI but the messages are still sent and can be read by anyone who has access to the blockchain.
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
			"ratio":    {Offset: 2, Initial: mm.T(0), Capacity: mm.T(0), X: 160, Y: 150},
		},
		Transitions: map[string]mm.Transition{
			msg: {X: 160, Y: 50},
		},
		Arrows: []mm.Arrow{
			{Source: "$account", Target: msg},
			{Source: msg, Target: toAddress},
			{Source: "ratio", Target: msg, Inhibit: true},
		},
	}
}

func exampleDither(cur realm, msg string, toAddress string) {
	m := dither(msg, toAddress)
	_ = m // call m.Execute() to verify model action
	// in reality users send messages directly using the memo field
	std.Emit("DITHER", "msg", msg, "toAddress", toAddress)
}
