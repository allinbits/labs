# GRC000 as a "Little Language"

In this document, we’ll explore how the GRC000 model can be viewed as a **Little Language** or **Domain-Specific Language (DSL)**,
specifically a **nested language**. 

This means that the model is not just a collection of functions and types,
but rather a structured way to express complex behaviors using simpler components.


---

## 1. Primitives as Vocabulary
At the bottom, you have the **Petri-net primitives** from `mm.New`:

- **Place** → noun (state: `$wallet`, `$recipient`, `$minter`)
- **Transition** → verb (action: `transfer`, `mint`, `burn`)
- **Arrow** → grammar rule (mapping how verbs consume/produce nouns)

This is like having the alphabet and grammar rules of your *inner* language.

---

## 2. Combinators as Phrases
`GRC000_Wallet`, `GRC000_Transfer`, and `GRC000_MintBurn` are **phrases or idioms** in this inner language — they’re little *sentences* written in Petri-net terms that say things like:

- “A wallet has tokens”
- “A transfer moves tokens from `$wallet` to `$recipient`”
- “A minter can mint or burn tokens”

Go **functions** serve as combinators that return syntactic units in the inner Petri-net language.

---

## 3. Model Composition as Nested Syntax
`GRC000_Token` doesn’t write a new Petri net from scratch — it **nests** these smaller “phrases” together.

This is like building a paragraph out of sentences: the *outer* Go syntax says:

```go
mm.New(
    GRC000_Wallet(opts),
    GRC000_Transfer(opts),
    GRC000_MintBurn(opts),
    map[string]interface{}{"version": "v0"},
)
```

…which in the *inner* Petri-net language means:

> “Define a token model that has a wallet, can transfer, and can mint/burn.”

---

## 4. Rendering as Translation
Finally, `Render(path string)` is a **translator** from your nested Petri-net language into another output language (Markdown + SVG thumbnail). This is like going from a source language to a compiled binary or a rendered HTML page.

---

### Why Models resembled a Nested Language
- **Outer language** → Go: types, functions, control flow, maps, etc.
- **Inner language** → Petri-net model: places, transitions, arrows, composition.
- Models are **composed** by nesting inner-language constructs as arguments to `mm.New`.
- This creates a *layered syntax*, where Go’s function composition mirrors the grammar of the modeling language.

---

### Linguistic Analogy
- `mm.New` → **Sentence constructor**
- `GRC000_Wallet` / `GRC000_Transfer` / `GRC000_MintBurn` → **Idioms / clauses**
- `GRC000_Token` → **Paragraph composition**
- `Render()` → **Translation** into another language (Markdown + SVG)