package metamodel

import (
 mm "gno.land/p/metamodel000"
)

var lotkaVolterraDescription = `
This is a Lotka-Volterra (predator-prey) model.

Places (token counts):
- rabbits: population of prey
- wolves: population of predators

Transitions (events):
- birth: a rabbit reproduces (net +1 rabbit)
- predation: a wolf eats a rabbit (net -1 rabbit, +1 wolf)
- death: a wolf dies naturally (net -1 wolf)

Notes:
- Stoichiometry is encoded by duplicating arrows (e.g., 1 in, 2 out -> net +1).
- This is a minimal illustrative net; you can add carrying capacity, seasonal effects, or food chains.

Reference: [AlgebraicJulia/Petri.jl](https://github.com/AlgebraicJulia/Petri.jl/blob/516cc0df965f222bfdc7fb306d622c2bf120e898/examples/lotka-volterra.jl)
`

func init() {
 lvModel := lotkaVolterra()
 lvModel.Binding = func(_ string) string {
  return lotkaVolterraDescription + lvModel.ToMarkdown()
 }
 keywords := []string{
  "lotka-volterra", "predator", "prey", "rabbits", "wolves",
  "population", "ecology", "petri-net",
 }
 register("Lotka-Volterra", lvModel, keywords...)
}

func lotkaVolterra() *mm.Model {
 places := map[string]mm.Place{
  "rabbits": {Offset: 0, Initial: mm.T(100), Capacity: mm.T(0), X: 60,  Y: 80},
  "wolves":  {Offset: 1, Initial: mm.T(10),  Capacity: mm.T(0), X: 60,  Y: 180},
 }

 transitions := map[string]mm.Transition{
  "birth":     {Label: "birth", Offset: 0, X: 220, Y: 80},
  "predation": {Label: "predation", Offset: 1, X: 220, Y: 130},
  "death":     {Label: "death", Offset: 2, X: 220, Y: 180},
 }

 arrows := []mm.Arrow{
  // birth: rabbits -> rabbits (net +1)
  {Source: "rabbits", Target: "birth"},
  {Source: "birth", Target: "rabbits", Weight: mm.T(2)},

  // predation: wolves + rabbits -> wolves (net -1 rabbit, +1 wolf)
  {Source: "wolves", Target: "predation"},
  {Source: "rabbits", Target: "predation"},
  {Source: "predation", Target: "wolves", Weight: mm.T(2)},

  // death: wolves -> (sink)
  {Source: "wolves", Target: "death"},
 }

 return &mm.Model{
  Places:      places,
  Transitions: transitions,
  Arrows:      arrows,
 }
}