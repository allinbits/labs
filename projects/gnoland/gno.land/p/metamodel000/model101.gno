package metamodel

var model101Intro = `
The **metamodel** library provides a foundation for modeling dynamic systems using **places**, **transitions**, and **arrows**, grounded in the theory of **Petri nets**. It powers tools like [pflow.xyz](https://pflow.xyz), which lets users visually design, simulate, and export executable models.

### What is a Metamodel?

`

var model101Description = `
[![pflow](https://pflow.dev/img/zb2rhgiVZBVmUHsTUyr63mjFMuVksT3zqFMBGtoxzJyYkJUNv.svg)](https://pflow.dev/p/zb2rhgiVZBVmUHsTUyr63mjFMuVksT3zqFMBGtoxzJyYkJUNv/)

#### Core Concepts

- **Place**: (Circle) A container for tokens, representing discrete states, resources, or entities. Each place has optional capacity limits and can be initialized with a specific number of tokens. Places can also be **typed** or **colored**, carrying structured values beyond integers.

- **Transition**: (Square) An atomic operation or event that consumes tokens from input places and produces tokens to output places. Transitions are only *enabled* when all their input conditions are met. In pflow, transitions can also have **rates** (for continuous simulation) or **guards** (logic conditions).

- **Arrow**: (Line) A directed connection between places and transitions. Each arrow has a **weight**, defining how many tokens are moved. Arrows can also be **inhibitory** (preventing a transition if tokens exist), enabling conditional or mutual exclusion logic.

- **Model**: A composition of places, transitions, and arrows into a structured system. Models in pflow can be saved, shared, exported to SVG or JSON, and simulated step-by-step or continuously. They support **composability** (nesting models as subnets), **parameter sweeps**, and **visual feedback**.

#### Extended Features

- **Tooling**: The library provides a toolkit for publishing models on your gno.land realm
- **Modular Design**: Subnets and reusable patterns can be embedded within larger models.
- **Interactive Simulation**: Visual Tools allow users to click transitions to fire them, explore enabled states, and debug logic.
- **Continuous Simulation**: Models can be extended to support continuous dynamics, where transitions fire at rates over time rather than instantaneously. This allows modeling of fluid systems, such as economic flows or resource consumption.
- **ODE Export**: Continuous models can be exported to Julia for differential equation solving using [Petri.jl](https://github.com/AlgebraicJulia/Petri.jl) and [pflow-jl](https://github.com/pflow-xyz/pflow-jl)

#### Terms
- **Metamodel**: A framework for modeling dynamic systems using places, transitions, and arrows, inspired by Petri nets.
- **Token**: A unit of state within a place, representing resources, entities, or values. Tokens can be integers or structured data.
- **Enabled**: A transition is enabled when all its input places have enough tokens to satisfy
the transition's requirements. Enabled transitions can be fired.
- **Firing**: The process of a transition consuming tokens from input places and producing tokens
to output places. Firing is an atomic operation that changes the state of the model.
- **Capacity**: The maximum number of tokens a place can hold. If a place reaches its capacity, no more tokens can be added until some are consumed.
- **Rate**: For continuous transitions, the rate at which tokens are produced or consumed over time. This allows modeling of fluid dynamics where changes occur continuously rather than instantaneously.
- **Guard**: A logical condition that must be satisfied for a transition to fire. Guards can be used to implement complex logic and constraints within the model.
- **Coloring**: A way to extend places and tokens with structured data, allowing for richer semantics beyond simple integers. Colored tokens can carry additional information, enabling more complex interactions and behaviors.
- **Composability**: The ability to combine smaller models into larger ones, allowing for modular design and reuse of patterns. This enables building complex systems from simpler components.
- **Inhibitory Arrows**: Arrows that prevent a transition from firing if tokens exist in the source place. This allows for conditional logic and mutual exclusion within the model.
- **Read Arc**: An arrow that allows a transition to read the number of tokens in a place without consuming them. This is useful for implementing logic that depends on the state of a place without modifying it.
- **Simulation**: The process of executing a model step-by-step or continuously, observing how tokens flow through places and transitions over time. Simulation can be used to validate logic, explore behavior, and visualize system dynamics.
- **Parameter Sweep**: A technique for exploring how changes in model parameters affect behavior. This allows users to test different configurations and understand the sensitivity of the model to various inputs.

#### Petri Net vs. Blockchain Analogy

How do Petri nets relate to blockchain systems?

The table below compares discrete and continuous Petri nets with blockchain concepts, highlighting how they model state transitions, token flows, and system dynamics.


| Concept         | Discrete Petri Net                                                                 | Continuous Petri Net                                                      | Blockchain Analogy                                                                                                         |
|-----------------|-----------------------------------------------------------------------------------|---------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| Tokens          | Individual units (integers) represent atomic state – often 0 or 1.                | Tokens become real numbers, representing fluid quantities or probabilities.| In blockchains: tokens (e.g., ETH, ATOM) are discrete balances, but gas usage, rewards, and slashing may be modeled as rates. |
| Transitions     | Fire once if enabled (step function).                                             | Fire continuously over time if enabled (rate function).                    | A blockchain transaction is a discrete event. But protocol-level mechanics like inflation, slashing decay, or staking reward emission resemble continuous flows. |
| Time            | Event-driven; transitions fire instantaneously in response to system state.        | Time-driven; modeled using ODEs (ordinary differential equations).         | Blockchain consensus (e.g. blocks every 6s) is discrete, but validator uptime, bonding, and APR accrue over time.          |
| Execution Mode  | Simulated step-by-step; transition fires consume/produce tokens.                  | Simulated by solving differential equations over time.                     | A blockchain ledger executes discrete state transitions. But validator incentives and governance voting power may drift continuously. |
| Concurrency     | Token availability controls which transitions can fire in parallel.                | Flow rates allow simultaneous, partially overlapping effects.              | Blockchains serialize transactions, but under the hood, many systems (e.g., mempool, gossip) operate concurrently and probabilistically. |
| Model Use       | Suited for modeling smart contract logic, protocol steps, message passing.         | Suited for modeling macroeconomic parameters, inflation curves, and staking dynamics. | Discrete: app layer, Continuous: tokenomics, liquidity models, staking behavior.                                           |
| Tooling         | Used in pflow.xyz (discrete simulation, structural validation).                    | Used in Petri.jl (ODE simulation, continuous analysis).                    | Blockchains use discrete VM execution, but models of long-term behavior require continuous approximations.                 |

`
// REVIEW: include information about colored nets
var model101Axioms = `
## Fungible Object Axioms

In the Logoverse, objects are the atomic units of a model.
They act as boundary places (ports) and preserve token identity across the system.

* As ports: objects label places in a model. Arrows then describe how an object transforms into another, or how tokens are created or destroyed.

* As arrows: objects determine the type of tokens that flow through them.

These axioms define the fundamental properties of "$objects" in the Logoverse:

### Axiom 1 — Uniqueness
Each "$object" has a unique identity in the model's set of objects.
Two objects are equal if and only if all of their behaviors coincide.

A given "$object" can be used in multiple places and transitions, but it must always refer to the same unique identity.

### Axiom 2 — Behavioral Identity
An "$object" is defined entirely by the set of transitions it participates in, both inbound and outbound.
This reflects the Yoneda principle: an object is its observable behavior in all contexts.

Places using a non-"$object" labels are interstitial, meaning they do not define an object identity,
but are used to hold tokens when in transit between "$objects".

### Axiom 3 — Openness
A leading "$" marks a port, which is an open boundary place.
Ports enable gluing models along shared "$objects".

### Axiom 4 — Extensibility
The set of objects is open under union.
This enables modular composition without redefining existing objects.

### Axiom 5 — Token Semantics
An "$object" when used as a port is not the token itself but the place that can hold tokens of some type.
Example: "$eth" is the object; ETH tokens flow through it.

When used as a transition, an "$object" defines how tokens of that type are transferred between places.

### Axiom 6 — Contextual Meaning
The meaning of an "$object" emerges from its participation in a model.
For example, "$coffee_beans" in a supply-chain net is not the same as "$coffee_beans" in a DAO-voting net, unless their transitions align.

Together, these axioms ground the Logoverse: objects are nodes of identity, defined by arrows, composable via ports, extensible by union, and can be used to label places or populate places as tokens.
`
func Tutorial101() *Model {
	m := model101()
	m.Binding = func(path string) string {
		switch path {
		case "intro":
			return model101Intro
		case "description":
			return model101Description
		case "markdown":
			return m.ToMarkdown()
		case "svg":
			return m.ToSvg()
		case "json":
			return m.ToJson()
		default:
		}
		return model101Intro +
			model101Description +
			model101Axioms
	}
	return m
}

func model101() *Model {
	places := map[string]Place{
		"start":  {Offset: 0, Initial: T(1), Capacity: T(1), X: 40, Y: 50},
		"finish": {Offset: 1, Capacity: T(1), X: 200, Y: 50},
	}
	transitions := map[string]Transition{
		"go": {X: 120, Y: 50},
	}
	arrows := []Arrow{
		{Source: "start", Target: "go"},
		{Source: "go", Target: "finish"},
	}
	return New(places, transitions, arrows, map[string]any{})
}
