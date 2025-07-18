# metamodel

> A metamodel is a model that defines the structure, rules, and constraints of other models — essentially, a model of models.
> It provides the schema or blueprint for how valid models should be constructed.

This GnoLand Library provides a framework for modeling with [Petri-net](https://en.wikipedia.org/wiki/Petri_net) style models.

## Overview

- Models are constructed using gno code.
    - Models are state-transition systems with some predefined places and transitions.
    - At runtime variables are bound to the model, and the model is executed.
    - Models can be used to define complex behaviors and interactions in a structured way.
- Models can be fully visualized in the GnoLand UI as SVG diagrams.
    - The visualization is generated from the model code, ensuring that the visual representation is always up-to-date with the model definition.
- Models are composable with each other.
- Models are exportable to be analyzed or used in other systems.
    - Julia nets here... 

### Using models for analysis and weighted choice decision-making
// FIXME: use pScore voting as an example
1. Formally define a model using the metamodel library in gno code.
   - It's a system of discrete state transformations formalized as a [Petri net](https://en.wikipedia.org/wiki/Petri_net) that can be used to represent and analyze the behavior of systems.
2. Each Model is executable in the GnoLand runtime, and visualized in markdown.
3. Model Data is make exportable to other languages or systems for analysis 
  - see [AlgebraicJulia/Petri.jl](github.com/AlgebraicJulia/Petri.jl) for an example of a Julia package that can work with these models.
  - This system can be directly converted to a dynamic system as an [Ordinary Differential Equation (ODE)](https://en.wikipedia.org/wiki/Ordinary_differential_equation).
   
#### pScore voting

FIXME: explain how this works 


### References

- [Open Petri Nets](https://arxiv.org/abs/1808.05415)
- [Additive Invariants of Open Petri Nets](https://arxiv.org/pdf/2303.01643)
    - [Additive Invariants of Open Petri Nets (video)](https://www.youtube.com/watch?v=OOuK6fRY0KY)
- [AlgebraicJulia/Petri.jl](https://github.com/AlgebraicJulia/Petri.jl)
- [Compositional Distributional Model of Meaning](https://www.cs.ox.ac.uk/files/2879/LambekFestPlain.pdf)