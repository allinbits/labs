package metamodel

import mm "gno.land/p/metamodel000"

var model101Intro = `
The **metamodel** library provides a foundation for modeling dynamic systems using **places**, **transitions**, and **arrows**, grounded in the theory of **Petri nets**. It powers tools like [pflow.xyz](https://pflow.xyz), which lets users visually design, simulate, and export executable models.

`

var model101Description = `

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

### Become A Model Citizen

Models can represent anything, from simple workflows to complex systems like economic models, supply chains, or even entire blockchain protocols.
The library is designed to be extensible, allowing users to bind model objects to other gno objects, enabling rich interactions and dynamic behaviors.

The goal is to provide a powerful yet intuitive framework for modeling dynamic systems, enabling users to explore
the behavior of their models, validate logic, and export them for execution or further analysis.

Submit your models to the public index to become a model citizen and share your work with the community!

`

func init() {
	model := model101()
	model.Binding = func(_ string) string {
		return model101Intro + model.ToMarkdown() + model101Description
	}
	keywords := []string{"metamodel", "modeling101", "modelCitizen"}
	register("Metamodel Codex", model, keywords...)
}

func model101() *mm.Model {
	places := map[string]mm.Place{
		"start":  {Offset: 0, Initial: mm.T(1), Capacity: mm.T(1), X: 40, Y: 50},
		"finish": {Offset: 1, Capacity: mm.T(1), X: 200, Y: 50},
	}
	transitions := map[string]mm.Transition{
		"go": {X: 120, Y: 50},
	}
	arrows := []mm.Arrow{
		{Source: "start", Target: "go"},
		{Source: "go", Target: "finish"},
	}
	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}
