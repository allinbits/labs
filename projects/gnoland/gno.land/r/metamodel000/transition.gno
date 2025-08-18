package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var singleTransitionDescription = `
This is a fundamental model with a single transition and no places.
It demonstrates the basic structure of a transition in the metamodel.

### What is a Transition?
A transition represents an event or action that can change the state of the system.
In this model, the transition is labeled "Change" and is initialized with no tokens.
It can be thought of as a point where the system can evolve or change its state.

`

func init() {
	model := singleTransition()
	model.Binding = func(_ string) string {
		return singleTransitionDescription + model.ToMarkdown()
	}
	keywords := []string{"place", "transition"}
	register("Transition Definition", model, keywords...)
}

func singleTransition() *mm.Model {
	transitions := map[string]mm.Transition{
		"Change": {Label: "Change", Offset: 0, X: 250, Y: 100},
	}
	return mm.New(transitions)
}
