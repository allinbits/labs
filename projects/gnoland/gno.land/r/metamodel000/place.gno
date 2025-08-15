package metamodel

import (
    mm "gno.land/p/metamodel000"
)

var singlePlaceDescription = `
This is a fundamental model with a single place and no transitions.
It demonstrates the basic structure of a place in the metamodel.

### What is a Place?
A place represents a state or condition in the system. It can hold tokens, which represent the
current state of that place. In this model, the place is initialized with one token.

`

func init() {
    model := singlePlace()
    model.Binding = func(_ string) string {
        return singlePlaceDescription + model.ToMarkdown()
    }
    keywords := []string{"place", "fundamental"}
    register("Place Definition", model, keywords...)
}

func singlePlace() *mm.Model {
    places := map[string]mm.Place{
        "Element": {Offset: 0, Initial: mm.T(1), Capacity: mm.T(0), X: 100, Y: 100},
    }
    return mm.New(places)
}