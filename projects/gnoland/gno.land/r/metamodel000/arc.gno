package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var basicCompositionDescription = `
This is a fundamental model with a single place and a single transition.
It demonstrates the basic structure of a place and a transition in the metamodel.

### What is an Arc?
An arc represents a connection between a place and a transition. It can carry tokens from the place
to the transition, indicating that the transition can fire when there are enough tokens in the place.

`

func init() {
	model := basicComposition()
	model.Binding = func(_ string) string {
		return basicCompositionDescription + model.ToMarkdown()
	}
	keywords := []string{"place", "transition", "arc"}
	register("Arc Definition", model, keywords...)
}

func basicComposition() *mm.Model {
	return mm.New(singlePlace(), singleTransition(), []mm.Arrow{
		{Source: "Element", Target: "Change"},
	})
}
