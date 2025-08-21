package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var paymentDescription = `
This model is a humorous take on the complexities of fiat payment systems,


### The Beige Labyrinth: A Comedy of Fiat Errors

This Petri Net is a travel diary for a single dollar trying to buy coffee.
Along the way it earns stamps from departments you did not know existed.

**Cast of Places**
- payer_wallet: Where hope begins.
- payment_intent: You clicked "Pay". A hero's journey starts.
- authorized: Bank says "probably yes", which is not "yes".
- escrow_hold: Time-out chair for money.
- debit_pending / credit_pending: Schrödinger's ledger entries.
- debit_posted / credit_posted: It happened, unless it didn't.
- settled -> queued -> sending -> sent -> received:
  The value express, stopping at every compliance town on the map.
- refunded / reversed / cancelled / failed: Four flavors of "nope".
- disputed / chargeback: The extended universe with a 180-day cliffhanger.
- fees_pool: Where tiny fees go to bulk up.
- payee_wallet: The mythical end state, sighted occasionally in the wild.

**Plot Twists (Transitions)**
- initiate -> authorize -> capture -> settle:
  Because "pay" is a four-act play with two intermissions.
- queue_send -> start_sending -> mark_sent -> mark_received:
  Four verbs to say "we mailed it".
- cancel / reverse / refund:
  Choose-your-own-bureaucracy.
- chargeback_open -> (win|loss):
  Courtroom drama for $3.17.
- post_debit / post_credit:
  Bookkeeping yoga: flow, stretch, breathe.
- fail_send:
  Your money tripped over a compliance memo.

**Fun Facts**
- "escrow_hold" is Latin for "we are thinking about it".
- "debit_pending" and "credit_pending" are twins separated at batch time.
- The "fees_pool" never seems to run dry. Scientists remain baffled.

**Moral**
In fiat land, value moves like a Rube Goldberg machine: every hop lowers risk for someone and raises time for everyone.
If this diagram looks complicated, that is not a bug. It is the business model.
`

func init() {
	paymentModel := payment()
	paymentModel.Binding = func(path string) string {
		return paymentDescription + paymentModel.ToMarkdown()
	}
	keywords := []string{"transaction", "fiat"}
	register("Payment", paymentModel, keywords...)
}

func payment() *mm.Model {
	places := map[string]mm.Place{
		"payer_wallet":    {X: 68, Y: 302},
		"payment_intent":  {X: 224, Y: 180},
		"authorized":      {X: 368, Y: 180},
		"debit_pending":   {X: 439, Y: 337},
		"debit_posted":    {X: 584, Y: 298},
		"debit_reversed":  {X: 590, Y: 497},
		"escrow_hold":     {X: 298, Y: 404},
		"cancelled":       {X: 1361, Y: 92},
		"reversed":        {X: 1351, Y: 542},
		"refunded":        {X: 1386, Y: 420},
		"failed":          {X: 1315, Y: 372},
		"capture":         {X: 512, Y: 180},
		"settled":         {X: 669, Y: 155},
		"queued":          {X: 800, Y: 180},
		"sending":         {X: 944, Y: 180},
		"sent":            {X: 1088, Y: 180},
		"received":        {X: 1232, Y: 180},
		"disputed":        {X: 957, Y: 391},
		"chargeback":      {X: 1418, Y: 494},
		"payee_wallet":    {X: 1412, Y: 210},
		"credit_pending":  {X: 513, Y: 159},
		"credit_posted":   {X: 989, Y: 308},
		"credit_reversed": {X: 724, Y: 457},
		"fees_pool":       {X: 73, Y: 488},
	}

	transitions := map[string]mm.Transition{
		"initiate":        {X: 157, Y: 249},
		"authorize":       {X: 296, Y: 220},
		"capture":         {X: 440, Y: 220},
		"settle":          {X: 599, Y: 203},
		"queue_send":      {X: 728, Y: 220},
		"start_sending":   {X: 872, Y: 220},
		"mark_sent":       {X: 1016, Y: 220},
		"mark_received":   {X: 1160, Y: 220},
		"cancel":          {X: 614, Y: 94},
		"reverse":         {X: 397, Y: 560},
		"refund":          {X: 639, Y: 386},
		"chargeback_open": {X: 715, Y: 331},
		"chargeback_win":  {X: 856, Y: 129},
		"chargeback_loss": {X: 1123, Y: 512},
		"fail_send":       {X: 1103, Y: 372},
		"post_debit":      {X: 145, Y: 550},
		"post_credit":     {X: 839, Y: 314},
		"reverse_debit":   {X: 511, Y: 425},
		"reverse_credit":  {X: 808, Y: 497},
		"deliver_funds":   {X: 1304, Y: 220},
		"release_hold":    {X: 162, Y: 351},
	}

	arcs := []mm.Arrow{
		{Source: "payer_wallet", Target: "initiate"},
		{Source: "initiate", Target: "payment_intent"},
		{Source: "payment_intent", Target: "authorize"},
		{Source: "authorize", Target: "authorized"},
		{Source: "authorize", Target: "escrow_hold"},
		{Source: "authorized", Target: "capture"},
		{Source: "escrow_hold", Target: "capture"},
		{Source: "capture", Target: "debit_pending"},
		{Source: "capture", Target: "credit_pending"},
		{Source: "debit_pending", Target: "settle"},
		{Source: "credit_pending", Target: "settle"},
		{Source: "settle", Target: "debit_posted"},
		{Source: "settle", Target: "credit_posted"},
		{Source: "settle", Target: "fees_pool"},
		{Source: "debit_posted", Target: "refund"},
		{Source: "credit_posted", Target: "refund"},
		{Source: "refund", Target: "refunded"},
		{Source: "refund", Target: "debit_reversed"},
		{Source: "refund", Target: "credit_reversed"},
		{Source: "refund", Target: "payer_wallet"},
		{Source: "payment_intent", Target: "cancel"},
		{Source: "cancel", Target: "cancelled"},
		{Source: "debit_pending", Target: "reverse"},
		{Source: "credit_pending", Target: "reverse"},
		{Source: "escrow_hold", Target: "reverse"},
		{Source: "reverse", Target: "reversed"},
		{Source: "reverse", Target: "debit_reversed"},
		{Source: "reverse", Target: "credit_reversed"},
		{Source: "reverse", Target: "payer_wallet"},
		{Source: "debit_posted", Target: "reverse_debit"},
		{Source: "reverse_debit", Target: "debit_reversed"},
		{Source: "credit_posted", Target: "reverse_credit"},
		{Source: "reverse_credit", Target: "credit_reversed"},
		{Source: "debit_posted", Target: "post_debit"},
		{Source: "post_debit", Target: "debit_posted"},
		{Source: "credit_pending", Target: "post_credit"},
		{Source: "post_credit", Target: "credit_posted"},
		{Source: "credit_posted", Target: "deliver_funds"},
		{Source: "deliver_funds", Target: "payee_wallet"},
		{Source: "escrow_hold", Target: "release_hold"},
		{Source: "release_hold", Target: "payer_wallet"},
		{Source: "settle", Target: "settled"},
		{Source: "settled", Target: "queue_send"},
		{Source: "queue_send", Target: "queued"},
		{Source: "queued", Target: "start_sending"},
		{Source: "start_sending", Target: "sending"},
		{Source: "sending", Target: "mark_sent"},
		{Source: "mark_sent", Target: "sent"},
		{Source: "sent", Target: "mark_received"},
		{Source: "mark_received", Target: "received"},
		{Source: "settled", Target: "chargeback_open"},
		{Source: "chargeback_open", Target: "disputed"},
		{Source: "disputed", Target: "chargeback_win"},
		{Source: "chargeback_win", Target: "settled"},
		{Source: "disputed", Target: "chargeback_loss"},
		{Source: "chargeback_loss", Target: "chargeback"},
		{Source: "chargeback_loss", Target: "debit_reversed"},
		{Source: "chargeback_loss", Target: "credit_reversed"},
		{Source: "sending", Target: "fail_send"},
		{Source: "fail_send", Target: "failed"},
	}

	return mm.New(places, transitions, arcs)
}
