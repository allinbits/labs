# **GRC-000 — Metamodel Token Standard**

**Status:** Draft **Version:** GRC-based core balance primitives,
but **composable-first** with Petri-net semantics.

---

## 1 Overview

**GRC-000** defines the **minimal, safe, deterministic** interface for fungible tokens on `gno.land`, with first-class support for **Petri-net composition**.  
The goal is not to ship every possible feature in one spec, but to define a **core set of primitives** — small, deterministic Petri-net fragments that can be composed into more complex systems.

---

## 2 Primitives — “Lemmas” of Token Logic

We call the core Petri-net fragments **primitives**.  
A primitive is like a **lemma** in mathematics:

- On its own, it may seem trivial or uninteresting.
- Its real power appears **when composed** with other primitives into larger, higher-level transaction models.
- Each primitive is **self-contained**, deterministic, and composable without modification.

For example:
- A **wallet primitive** defines “an account holds tokens.”
- A **transfer primitive** defines “tokens move from one account to another.”
- A **mint/burn primitive** defines “tokens are created or destroyed.”

By combining these lemmas, you can build a DEX, a staking module, a faucet, or a DAO treasury without rewriting the fundamentals.

---

## 3 Core Terminology

| Term        | Meaning |
|-------------|---------|
| **Account** | A `gno.land` address string. |
| **Amount**  | `uint64` by default. Future upgrade path to big integers via **GRC-010**. |
| **Module**  | A realm implementing this interface. |
| **Port**    | A named Petri-net boundary place (e.g. `$wallet`, `$recipient`, `$minter`) used for composition. |
| **Primitive** | A minimal Petri-net submodel that captures one atomic behavior, designed to be composed with others. |

---

## 4 Petri-Net Ports & Composition

The standard expresses wallet and token flows as **Petri-net primitives** using [`pflow/mm`](https://pflow.xyz).  
Named **ports** are preserved across compositions so the token net can slot directly into other transaction models.

---

### 4.1 Wallet Primitive

```go
func GRC000_Wallet() *mm.Model {
    return mm.New(map[string]mm.Place{
        "$wallet": {Offset: 0, Initial: mm.T(1), Capacity: mm.T(0), X: 60, Y: 60},
    })
}
```

---

### 4.2 Transfer Primitive

```go
func GRC000_Transfer() *mm.Model {
    return mm.New(
        map[string]mm.Place{
            "$wallet":    {Offset: 0, Initial: mm.T(1), X: 60,  Y: 60}, // sender
            "$recipient": {Offset: 1, Initial: mm.T(0), X: 240, Y: 60}, // recipient
        },
        map[string]mm.Transition{
            "transfer": {X: 150, Y: 60},
        },
        []mm.Arrow{
            {Source: "$wallet", Target: "transfer", Weight: mm.T(1)},
            {Source: "transfer", Target: "$recipient", Weight: mm.T(1)},
        },
    )
}
```

---

### 4.3 Mint / Burn Primitive

```go
func GRC000_MintBurn() *mm.Model {
    return mm.New(
        map[string]mm.Place{
            "$minter": {Offset: 0, Initial: mm.T(1), X: 60, Y: 140},
            "$wallet": {Offset: 1, Initial: mm.T(0), X: 240, Y: 140},
        },
        map[string]mm.Transition{
            "mint": {X: 150, Y: 140},
            "burn": {X: 150, Y: 200},
        },
        []mm.Arrow{
            {Source: "$minter", Target: "mint", Weight: mm.T(1)},
            {Source: "mint", Target: "$wallet", Weight: mm.T(1)},
            {Source: "$wallet", Target: "burn", Weight: mm.T(1)},
        },
    )
}
```

---

### 4.4 Composed Token Model

```go
func GRC000_Token() *mm.Model {
    return mm.New(
        GRC000_Wallet(),
        GRC000_Transfer(),
        GRC000_MintBurn(),
        map[string]interface{}{"version": "v0"}, // RenderOpts
    )
}
```

---

## 5 Composition Principle

> **Rule:** Port names remain stable across primitives.  
> **Benefit:** Any higher-level Petri-net (DEX, DAO, faucet, staking) can directly connect to `$wallet`, `$recipient`, or `$minter` without glue code.

---