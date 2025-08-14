package metamodel

import (
    mm "gno.land/p/metamodel000"
)

// Logoverse — A compositional universe of models about models.
//
// The Logoverse treats a metamodel as first-class: a model that defines
// the structure, rules, and constraints of other models. Models are authored
// in Gno, executed in the runtime, visualized as SVG, composed as subnets,
// and exported for external analysis (e.g., in Julia/Petri.jl or as ODEs).
// Decisions (e.g., pScore voting) can be modeled as weighted-choice flows
// over model-produced evidence.
//
// This file defines a single Petri-net model that captures that lifecycle
// and a rich description bound to the model for markdown rendering.

var logoverseOverview = `
# Logoverse — Metamodel of Models

> A **metamodel** is a model that defines the structure, rules, and constraints of other models — essentially, a *model of models*.
> It provides the schema or blueprint for how valid models should be constructed.

The **Logoverse** is the compositional space where such metamodels and their concrete models live, connect, and evolve. In this view:

- **Models are authored in Gno** as discrete state–transition systems (Petri nets).
  - They define places, transitions, and arcs with precise semantics.
  - At runtime, variables are bound to the model and transitions fire according to rules.
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
- [Additive Invariants of Open Petri Nets](https://arxiv.org/pdf/2303.01643)
  - [Video - presenting the opent petri-nets paper](https://www.youtube.com/watch?v=OOuK6fRY0KY)
- [AlgebraicJulia/Petri.jl](https://github.com/AlgebraicJulia/Petri.jl)
- [Compositional Distributional Model of Meaning](https://www.cs.ox.ac.uk/files/2879/LambekFestPlain.pdf)
`

var logoverseNotes = `
> **Ports & openness.** We treat leading $ places as *ports* (open boundary places) to make composition explicit.
Ports make it easy to wire models together while preserving invariants (cf. open Petri nets).
`

// logoverseModel builds a Petri net that encodes the lifecycle:
// ideas → metamodel schema → concrete model → runtime execution →
// visualization | composition | export → analysis → decision (pScore).
func logoverseModel() *mm.Model {
    places := map[string]mm.Place{
        "$ideas":       {Offset: 0, Initial: mm.T(1), Capacity: mm.T(0), X: 40,  Y: 60},
        "$schemas":     {Offset: 1, Initial: mm.T(0), Capacity: mm.T(0), X: 140, Y: 60},
        "$models":      {Offset: 2, Initial: mm.T(0), Capacity: mm.T(0), X: 240, Y: 60},
        "$runtime":     {Offset: 3, Initial: mm.T(0), Capacity: mm.T(0), X: 340, Y: 60},
        "$viz":         {Offset: 4, Initial: mm.T(0), Capacity: mm.T(0), X: 440, Y: 30},
        "$compose":     {Offset: 5, Initial: mm.T(0), Capacity: mm.T(0), X: 440, Y: 90},
        "$exports":     {Offset: 6, Initial: mm.T(0), Capacity: mm.T(0), X: 540, Y: 60},
        "$analysis":    {Offset: 7, Initial: mm.T(0), Capacity: mm.T(0), X: 640, Y: 60},
        "$decisions":   {Offset: 8, Initial: mm.T(0), Capacity: mm.T(0), X: 740, Y: 60},
    }

    transitions := map[string]mm.Transition{
        "Formalize":   {X: 90,  Y: 60},  // ideas → schemas
        "Instantiate": {X: 190, Y: 60},  // schemas → models
        "Execute":     {X: 290, Y: 60},  // models → runtime
        "RenderSVG":   {X: 390, Y: 30},  // models → viz
        "Compose":     {X: 390, Y: 90},  // models → compose (as subnet)
        "ExportJulia": {X: 490, Y: 45},  // models → exports
        "ExportODE":   {X: 490, Y: 75},  // models → exports
        "Analyze":     {X: 590, Y: 60},  // exports|runtime → analysis
        "pScoreVote":  {X: 690, Y: 60},  // analysis → decisions
    }

    arrows := []mm.Arrow{
        // ideas → Formalize → schemas
        {Source: "$ideas", Target: "Formalize", Weight: mm.T(1)},
        {Source: "Formalize", Target: "$schemas", Weight: mm.T(1)},

        // schemas → Instantiate → models
        {Source: "$schemas", Target: "Instantiate", Weight: mm.T(1)},
        {Source: "Instantiate", Target: "$models", Weight: mm.T(1)},

        // models → Execute → runtime
        {Source: "$models", Target: "Execute", Weight: mm.T(1)},
        {Source: "Execute", Target: "$runtime", Weight: mm.T(1)},

        // models → visualization / composition branches
        {Source: "$models", Target: "RenderSVG", Weight: mm.T(1)},
        {Source: "RenderSVG", Target: "$viz", Weight: mm.T(1)},
        {Source: "$models", Target: "Compose", Weight: mm.T(1)},
        {Source: "Compose", Target: "$compose", Weight: mm.T(1)},

        // models → export (two modes)
        {Source: "$models", Target: "ExportJulia", Weight: mm.T(1)},
        {Source: "ExportJulia", Target: "$exports", Weight: mm.T(1)},
        {Source: "$models", Target: "ExportODE", Weight: mm.T(1)},
        {Source: "ExportODE", Target: "$exports", Weight: mm.T(1)},

        // exports and/or runtime evidence → analysis
        {Source: "$exports", Target: "Analyze", Weight: mm.T(1)},
        {Source: "$runtime", Target: "Analyze", Weight: mm.T(1)},
        {Source: "Analyze", Target: "$analysis", Weight: mm.T(1)},

        // analysis evidence → pScore decision distribution
        {Source: "$analysis", Target: "pScoreVote", Weight: mm.T(1)},
        {Source: "pScoreVote", Target: "$decisions", Weight: mm.T(1)},
    }

    return &mm.Model{Places: places, Transitions: transitions, Arrows: arrows}
}

// glueMarkdown binds the narrative to the rendered model markdown.
func glueMarkdown(m *mm.Model) string {
    return logoverseOverview + "\n" + logoverseHowTo + "\n" + logoverseNotes + "\n" + m.ToMarkdown() + "\n" + logoverseReferences
}

func init() {
    m := logoverseModel()
    m.Binding = func(_ string) string { return glueMarkdown(m) }

    keywords := []string{
        "metamodel", "petri", "open nets", "ports", "composition",
        "visualization", "svg", "export", "julia", "ode", "analysis", "pscore",
    }

    register("Logoverse — Metamodel of Models", m, keywords...)
}
