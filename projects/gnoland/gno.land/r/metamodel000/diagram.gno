package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var docReviewDescription = `
This model replicates [metamodel000:coffee-shop](metamodel000:coffee-shop) using the ImportDiagram feature.

`

func init() {
	diagram := `
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
	model := mm.ImportDiagram(diagram)
	model.Binding = func(_ string) string {
		return docReviewDescription + model.ToMarkdown()
	}
	register("ImportDiagram", model, "document", "review", "workflow", "approval")
}
