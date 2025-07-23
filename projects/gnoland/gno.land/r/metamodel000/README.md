# Introducing `p/metamodel000` as a Categorical Petri Net Model

## Abstract

This document introduces the `r/metamodel` realm on Gno.land using `metamodel.Model` as a foundational primitive
for modeling logic and computation using **categorical Petri nets**.

We describe the categorical structure embedded in this module and explain how functional code corresponds to categorical semantics,
specifically the Grothendieck construction, bicategories, and fibered state spaces.

---

## 1. Overview of `r/metamodel000`

The `metamodel000` package provides a minimal implementation of a Petri-net-style model. It abstracts system state into **places**, **transitions**, and **arrows**, with each Petri net representing a process over discrete resources (tokens).

### Example Function: `transfer()`

```go
// transfer creates a model to transfer tokens from a wallet to a specified address.
func transfer(toAddress string, action string, multiple int64) *mm.Model {
	return &mm.Model{
		Places: map[string]mm.Place{
			"$wallet": {Offset: 0, Initial: mm.T(9), Capacity: mm.T(0), X: 20, Y: 50},
			toAddress: {Offset: 0, Initial: mm.T(0), Capacity: mm.T(0), X: 270, Y: 50},
		},
		Transitions: map[string]mm.Transition{
			action: {X: 150, Y: 50},
		},
		Arrows: []mm.Arrow{
			{Source: "$wallet", Target: action, Weight: mm.T(multiple)},
			{Source: action, Target: toAddress, Weight: mm.T(multiple)},
		},
	}
}
```

---

## 2. Categorical Semantics

### 2.1 Places and Transitions as Objects and Morphisms

In categorical terms:

- **Places** are *objects* in a category.
- **Transitions** are *morphisms* (arrows) representing token flow.
- **Arcs (Arrows)** define the relationships between places and transitions, enforcing input/output conditions.

### 2.2 Petri Nets as Functors

We may view a Petri net as a **functor**:

```text
T: Time → States
```

This functor encodes state evolution over discrete time. Each transition fires in sequence, yielding a trace of state.

### 2.3 Bicategory Interpretation

Each state-change step (e.g., firing a transition) is a 1-morphism. Higher-level concepts like **"completion"**, **"deadlock"**, or **"goal achieved"** can be encoded as 2-morphisms: evaluating or interpreting the meaning of paths or transitions.

### 2.4 Grothendieck Construction and Fibers

Using a functor `F: Cᵒᵖ → Cat`, we can associate a category of semantic labels (e.g., outcomes, annotations) to each marking. The **Grothendieck construction** builds a *total category* from these fibers, unifying state + meaning:

```text
∫F = category of (marking, interpretation)
```

---

## 3. Functional-Categorical Mapping

| Code Element  | Categorical Interpretation                       |
| ------------- | ------------------------------------------------ |
| `Places`      | Objects of the category                          |
| `Transitions` | Morphisms between places                         |
| `Arrows`      | Input/output relations for morphisms             |
| `Model`       | Diagram in a symmetric monoidal category         |
| `transfer()`  | Functor instantiating a categorical construction |

---

## 4. Additional Example: `coffeeShop()`

This model extends the base recipe for making coffee into a full **operational category**—capturing not just the brewing sequence, but also the **serving and payment logic**. Each step is modeled with categorical precision:

- Ingredients and tools (e.g. Water, Cup, Filter) are **objects**.
- Actions (e.g. BoilWater, BrewCoffee, Send) are **morphisms**.
- The **inhibit arc** between PourCoffee and Payment encodes a **negation constraint** — enforcing payment after service.

This turns a basic recipe (a linear process) into a **fibered process diagram**, capable of capturing both causality and policy.

```go
func coffeeShop() *mm.Model {
	// full function definition omitted for brevity
	// see full implementation for structure of places, transitions, and arrows
}
```

From a categorical perspective, this model represents an **enriched process net**, layered with business logic, resource dependencies, and temporal ordering. The inclusion of ordering and credit handling defines a **richer Grothendieck fiber** over each state, representing both production and semantic status.

---

## 5. Implications and Extensions

The categorical foundation allows:

- Composability: build complex models from submodels
- Analysis: use homotopy or rewriting theory on transition graphs
- Semantics: attach evaluations, policies, or scores as fibers

This design enables a wide range of modeling — from economic flows to voting semantics — all embedded within the executable syntax of Gno.

---

## 6. Formal Analysis with Petri Nets: `pscore.gno`

The `pscore.gno` module builds on the `metamodel000` foundation to perform **formal evaluation of proposals** using weighted Petri nets.
Here, a proposal's *impact* and *cost* are encoded as tokens, and scoring is evaluated by tracking flow through transitions that represent policy constraints.

### 6.1 Objective Function as a Petri Net

Proposals in this system are scored not just by isolated votes, but by their interaction within a bounded budget and competitive environment. The Petri net:

- Models **proposals** as token sources
- Models **resource limits** (e.g. budget) as place constraints
- Models **decision policies** as transition guards

### 6.2 Optimization via Token Flow

The net evolves under firing rules constrained by token availability and guard logic. The process of "firing" transitions yields:

- A selection of proposals
- A net score
- Remaining budget or capacity

Thus, execution of the Petri net becomes equivalent to solving an **optimization problem**.

### 6.3 Categorical Framing of Evaluation

This system introduces:

- A **fiber** of evaluation semantics over each decision state
- A **functor** from proposals to execution traces
- A **bifunctor** for scoring impact × cost → score

These semantics extend the base Petri net into a full **evaluation category**, with morphisms capturing score evolution, and compositions representing aggregated decisions.

### 6.4 Implications

- Model-checking becomes *score validation*
- Invariants can enforce fairness or diversity
- Transitions can express logical constraints, quorum, or delay

This demonstrates that not only execution, but **governance evaluation** can be modeled in categorical terms, producing a traceable, reproducible, and analyzable policy layer.

---

## 7. Conclusion

The `r/metamodel000` module defines not just a syntax for logic, but a semantics grounded in category theory. With places and transitions forming a categorical structure, and annotations forming a fibered layer, we set the stage for a new kind of computation: **structured, semantic, and composable by design**.

---

**Keywords**: Petri nets, category theory, Grothendieck construction, Gno.land, bicategories, fibered categories, metamodels, semantic modeling, proposal scoring, formal governance analysis

