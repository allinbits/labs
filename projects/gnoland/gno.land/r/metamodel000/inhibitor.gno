package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var inhibitorArcDescription = `
This is a fundamental model with a single place and a single transition,
demonstrating the concept of an inhibitor arc.

### What is an Inhibitor Arc?
An inhibitor arc is a special type of connection between a place and a transition.
It prevents the transition from firing if there are tokens in the place.

NOTE: inhibitor arcs can also be called "read arcs" since they don't consume tokens.

`

func init() {
	model := inhibitorArc()
	model.Binding = func(_ string) string {
		return inhibitorArcDescription + model.ToMarkdown()
	}
	keywords := []string{"place", "transition", "fundamental", "arc", "inhibitor", "read-arc"}
	register("Inhibitor Arc Definition", model, keywords...)
}

func inhibitorArc() *mm.Model {
    return mm.New(singlePlace(), singleTransition(), []mm.Arrow{
        {Source: "Element", Target: "Change", Inhibit: true},
    })
}
