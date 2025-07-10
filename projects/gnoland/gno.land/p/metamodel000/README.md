# metamodel

A model library for GnoLand, providing a framework for defining and using Petri-nets.

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

### What is a model?

FIXME


### References

- [Open Petri Nets](https://arxiv.org/abs/1808.05415)
- [Additive Invariants of Open Petri Nets](https://arxiv.org/pdf/2303.01643)
    - [Additive Invariants of Open Petri Nets (video)](https://www.youtube.com/watch?v=OOuK6fRY0KY)
- [AlgebraicJulia/Petri.jl](https://github.com/AlgebraicJulia/Petri.jl)