package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var overview string = `
**pScore Voting** is a new governance primitive that helps DAOs and decentralized collectives prioritize projects based on **community-scored value** and **perceived cost-effectiveness**. Instead of voting *for* or *against* isolated proposals, participants **score each initiative** on two axes:

- **Impact (Value Score)** – “How important is this project to the community?”
- **Efficiency (Cost Score)** – “Is the cost justified by the expected benefit?”

These scores are processed by a formal optimization model
(e.g., a **Petri-net-backed knapsack**), which ranks and selects projects based on **aggregate utility under budget constraints**.
`

func init() {
	exampleModel := pScoreVoting(100_000, proposals)

	register("pscore", func(_ string) string {
		return overview + exampleModel.ToMarkdown()
	})
}

func pScoreVoting(budget int, proposals []Proposal) *mm.Model {
	places := map[string]mm.Place{
		"budget": {Offset: 0, Initial: mm.T(budget), Capacity: mm.T(1), X: 40, Y: 100},
		"value":  {Offset: 0, Initial: mm.T(0), Capacity: mm.T(1), X: 340, Y: 100},
		"spent":  {Offset: 0, Initial: mm.T(0), Capacity: mm.T(1), X: 340, Y: 200 + 50*len(proposals)},
	}

	arrows := []mm.Arrow{}
	transitions := map[string]mm.Transition{}

	for i, proposal := range proposals {
		x := 180            // Keep all proposals at the same X coordinate
		y := 200 + (i * 50) // Adjust Y position for vertical spacing

		// Create a transition for voting on the proposal
		action := proposal.id
		transitions[action] = mm.Transition{
			Label:  proposal.name,
			Offset: 0,
			X:      x,
			Y:      y,
		}
		// Create an arrow from the budget to the proposal vote transition
		arrows = append(arrows, mm.Arrow{
			Source: "budget",
			Target: action,
			Weight: mm.T(proposal.cost), // Use proposal cost as weight
		})

		// arrow from action to the value place
		arrows = append(arrows, mm.Arrow{
			Source: action,
			Target: "value",
			Weight: mm.T(proposal.value), // Use proposal value as weight
		})
		// arrow from action to the spent place
		arrows = append(arrows, mm.Arrow{
			Source: action,
			Target: "spent",
			Weight: mm.T(proposal.cost), // Use proposal cost as weight
		})
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}

type Proposal struct {
	id          string
	name        string
	description string
	cost        int
	value       int
	votes       map[string]int
}

var proposals = []Proposal{
	{
		id:          "p001",
		name:        "Realm Marketplace",
		description: "A smart contract marketplace for trading and discovering realms.",
		cost:        80_000,
		value:       100,
		votes:       map[string]int{},
	},
	{
		id:          "p002",
		name:        "GnoFrames Toolkit",
		description: "Dev toolkit for creating Farcaster-style Frames on gno.land.",
		cost:        30_000,
		value:       100,
		votes:       map[string]int{},
	},
	{
		id:          "p003",
		name:        "Sprite Canvas Upgrade",
		description: "Upgrade pixel sprite editor with animation and layer support.",
		cost:        20_000,
		value:       100,
		votes:       map[string]int{},
	},
}
