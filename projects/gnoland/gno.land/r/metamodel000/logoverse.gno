package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var logoverseOverview = `
The **Logoverse** is the compositional space where ideas, models, and objects can live, connect, and evolve.


# Logoverse — Metamodel of Models

> A **metamodel** is a model that defines the structure, rules, and constraints of other models — essentially, a *model of models*.
> It provides the schema or blueprint for how valid models should be constructed.
- **Models are authored in Gno** as discrete state–transition systems (Petri nets).
  - Objects are defined as places (variables) with unique identities (e.g., $eth, $btc, $coffee_beans).
  - We can define $objects in terms of places, transitions, and arcs with precise semantics.
  - At runtime, variables are bound to the objects and transitions fire according to rules.
- **Models are visualized** as SVG diagrams auto-generated from source, ensuring the diagram always matches the code.
- **Models compose**: small, trustworthy fragments ("primitives") are plugged together via boundary ports to form larger systems.
- **Models export**: structures and traces can be exported for analysis or interop (e.g., Julia's AlgebraicJulia/Petri.jl, or mapped to ODEs).
- **Models inform decisions**: analysis yields evidence that can feed **pScore** (weighted-choice) voting or other governance flows.

The Logoverse therefore links *formal specification*, *execution*, *visualization*, *composition*, *export*, *analysis*, and *decision-making* in one consistent loop.
`

var logoverseHowTo = `
## Using models for analysis and weighted-choice decision‑making

1. **Formally define** a model using the metamodel library (a Petri net with typed places/ports and transitions).
2. **Execute and visualize** it in the Gno runtime; the markdown view stays in sync with the code.
3. **Export** the structure or runs to other systems:
   - Use **AlgebraicJulia/Petri.jl** for compositional analysis and rewriting.
   - Map discrete dynamics to a continuous **ODE** when appropriate for system‑level studies.
4. **Aggregate evidence** from analysis into a decision procedure like **pScore**:
   - pScore treats each option as a sink of weighted support.
   - Evidence tokens (scores, proofs, or signals) flow through normalization and aggregation transitions.
   - The resulting distribution represents community preference under declared weights.

This closes the loop from *specification → execution → evidence → decision*.
`

var logoverseReferences = `
## References
- [Open Petri Nets](https://arxiv.org/abs/1808.05415)
- [Structured Cospans](https://arxiv.org/abs/1911.04630)
- [Additive Invariants of Open Petri Nets](https://arxiv.org/pdf/2303.01643)
  - [Video - presenting open petri-nets](https://www.youtube.com/watch?v=OOuK6fRY0KY)
- [AlgebraicJulia/Petri.jl](https://github.com/AlgebraicJulia/Petri.jl)
- [Compositional Distributional Model of Meaning](https://www.cs.ox.ac.uk/files/2879/LambekFestPlain.pdf)
`

var logoverseNotes = `
> **Ports & openness.** We treat leading $ places as *ports* (open boundary places) to make composition explicit.
Ports make it easy to wire models together while preserving invariants (cf. open Petri nets).
`

// logoverseModel builds a circular Petri net encoding the lifecycle:
// ideas → schemas → models → runtime → analysis → decisions → ideas (loop)
// with visualization, composition, and exports radiating from the main cycle.
func logoverseModel() *mm.Model {
	places := map[string]mm.Place{
		"$ideas":     {X: 56, Y: 185},
		"$gnolang":   {X: 248, Y: 259},
		"$models":    {X: 471, Y: 259},
		"$runtime":   {X: 713, Y: 185},
		"$analysis":  {X: 470, Y: 118},
		"$decisions": {X: 251, Y: 120},
		"$viz":       {X: 176, Y: 497},
		"$objects":   {X: 629, Y: 489},
		"$exports":   {X: 363, Y: 498},
		"$rss":       {X: 900, Y: 416},
		"$ical":      {X: 900, Y: 509},
	}

	transitions := map[string]mm.Transition{
		"Formalize":   {X: 150, Y: 259},
		"Instantiate": {X: 361, Y: 259},
		"Execute":     {X: 618, Y: 253},
		"Analyze":     {X: 601, Y: 119},
		"pScoreVote":  {X: 356, Y: 119},
		"Reignite":    {X: 150, Y: 121},
		"RenderSVG":   {X: 172, Y: 361},
		"Compose":     {X: 563, Y: 368},
		"ExportJulia": {X: 296, Y: 366},
		"ExportODE":   {X: 427, Y: 371},
		"Recompose":   {X: 684, Y: 368},
		"Feed":        {X: 781, Y: 419},
		"Calendar":    {X: 786, Y: 506},
	}

	arrows := []mm.Arrow{
		{Source: "$ideas", Target: "Formalize"},
		{Source: "Formalize", Target: "$gnolang"},
		{Source: "$gnolang", Target: "Instantiate"},
		{Source: "Instantiate", Target: "$models"},
		{Source: "$models", Target: "Execute"},
		{Source: "Execute", Target: "$runtime"},
		{Source: "$runtime", Target: "Analyze"},
		{Source: "Analyze", Target: "$analysis"},
		{Source: "$analysis", Target: "pScoreVote"},
		{Source: "pScoreVote", Target: "$decisions"},
		{Source: "$decisions", Target: "Reignite"},
		{Source: "Reignite", Target: "$ideas"},
		{Source: "$models", Target: "RenderSVG"},
		{Source: "RenderSVG", Target: "$viz"},
		{Source: "$models", Target: "Compose"},
		{Source: "Compose", Target: "$objects"},
		{Source: "$models", Target: "ExportJulia"},
		{Source: "ExportJulia", Target: "$exports"},
		{Source: "$models", Target: "ExportODE"},
		{Source: "ExportODE", Target: "$exports"},
		{Source: "$objects", Target: "Recompose"},
		{Source: "Recompose", Target: "$models"},
		{Source: "$objects", Target: "Feed"},
		{Source: "Feed", Target: "$rss"},
		{Source: "$objects", Target: "Calendar"},
		{Source: "Calendar", Target: "$ical"},
	}

	return &mm.Model{Places: places, Transitions: transitions, Arrows: arrows}
}

// glueMarkdown binds the narrative to the rendered model markdown.
func glueMarkdown(m *mm.Model) string {
	return logoverseOverview + "\n" + logoverseHowTo + "\n" + logoverseNotes + "\n" +
		"[![pflow](https://pflow.dev/img/zb2rhg8szbR6m3xXJuiGhTAZRG6BD1duTsmQoUtaJQSfWVnYo.svg)](https://pflow.dev/p/zb2rhg8szbR6m3xXJuiGhTAZRG6BD1duTsmQoUtaJQSfWVnYo/)" +
		logoverseReferences
}

func init() {
	m := logoverseModel()
	m.Binding = func(_ string) string { return glueMarkdown(m) }

	keywords := []string{
		"metamodel", "petri", "open nets", "ports", "composition",
		"visualization", "svg", "export", "julia", "ode", "analysis", "pscore",
	}

	register("Logoverse Metamodel-of-Models", m, keywords...)
}
