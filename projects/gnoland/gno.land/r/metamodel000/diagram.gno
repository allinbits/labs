package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var docReviewDescription = `
This model replicates [metamodel000:coffee-shop](/r/metamodel000:coffee-shop) using the ImportDiagram feature.

It includes three separate diagrams:
1. **States Only**: This diagram shows the states of the coffee-making process without actions
2. **Actions Only**: This diagram shows the actions taken in the coffee-making process without states
3. **Workflow**: This diagram combines both states and actions to illustrate the complete workflow of
    making coffee, from boiling water to crediting payment.

Notice how we can isolate the system into sub-diagrams by eliminating either states or actions.

---

### Notes on the Forgetful Functor

In category theory, a *forgetful functor* maps a rich structure to a simpler one by "forgetting" some of its data.
Here, we see a similar move:

- **Workflow → States Only**: We "forget" the transitions (actions) and retain only the objects (places/states).
- **Workflow → Actions Only**: We "forget" the states and keep only the morphisms (transitions).

This mirrors the idea that a Petri net, as a category of states and transitions, can be projected into simpler categories by discarding part of the structure.
What remains is still meaningful, but less expressive.

These projections illustrate how *forgetful functors* help us navigate between different levels of abstraction.

`

var statesOnly = `
$Water --> $BoiledWater
$CoffeeBeans --> $GroundCoffee
$BoiledWater --> $GroundCoffee
$GroundCoffee --> $CoffeeInPot
$Filter --> $CoffeeInPot
$CoffeeInPot --> $CupOfCoffee
$Cup --> $CupOfCoffee
$Pending --> $Sent
$Sent --> $Payment
`
var actionsOnly = `
BoilWater --> BrewCoffee
GrindBeans --> BrewCoffee
BrewCoffee --> PourCoffee
Send --> Credit
`

// workflow
var diagram = `
$Water --> BoilWater
BoilWater --> $BoiledWater
$CoffeeBeans --> GrindBeans
GrindBeans --> $GroundCoffee
$BoiledWater --> BrewCoffee
$GroundCoffee --> BrewCoffee
$Filter --> BrewCoffee
BrewCoffee --> $CoffeeInPot
$CoffeeInPot --> PourCoffee
$Cup --> PourCoffee
$Pending --> Send
Send --> $Sent
$Sent --> Credit
Credit --> $Payment
PourCoffee -|> $Payment
`

var stateMachine = mm.ImportDiagram(statesOnly)
var sequenceDiagram = mm.ImportDiagram(actionsOnly)
var petriNet = mm.ImportDiagram(diagram)

func init() {
    model := mm.New(petriNet)
    model.Binding = func(_ string) string {
        return docReviewDescription + stateMachine.ToMarkdown() + sequenceDiagram.ToMarkdown() + petriNet.ToMarkdown()
    }
	register("ImportDiagram", model, "ascii-diagram", "coffee-shop", "only-places", "only-transitions", "forgetful-functor")
}
