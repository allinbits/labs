package metamodel

var model201Intro = `
The **continuous metamodel** extends Petri nets to support fluid dynamics, where tokens represent real quantities and transitions fire at rates over time. This enables modeling systems like resource flows, economic dynamics, and continuous processes.
`

var model201Description = `
### Continuous Petri Nets

- **Tokens**: Real numbers, representing fluid or probabilistic quantities.
- **Transitions**: Fire continuously at specified rates.
- **Use Cases**: Macroeconomic models, resource consumption, staking reward emission.

Try exporting to Julia for ODE simulation using [Petri.jl](https://github.com/AlgebraicJulia/Petri.jl).
`

func Tutorial201() *Model {
    m := model201()
    m.Binding = func(path string) string {
        switch path {
        case "intro":
            return model201Intro
        case "description":
            return model201Description
        case "markdown":
            return m.ToMarkdown()
        case "svg":
            return m.ToSvg()
        case "json":
            return m.ToJson()
        default:
        }
        return model201Intro + m.ToMarkdown() + model201Description
    }
    return m
}

func model201() *Model {
    places := map[string]Place{
        "fluid":  {Offset: 0, Initial: T(10.0), Capacity: T(100.0), X: 40, Y: 50},
        "sink":   {Offset: 1, Capacity: T(100.0), X: 200, Y: 50},
    }
    transitions := map[string]Transition{
        "flow": {X: 120, Y: 50, Rate: 0.9}, // Example rate for continuous flow
    }
    arrows := []Arrow{
        {Source: "fluid", Target: "flow", Weight: T(1.0)},
        {Source: "flow", Target: "sink", Weight: T(1.0)},
    }
    return New(places, transitions, arrows, map[string]any{})
}