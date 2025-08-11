# Append-Only Petri-Nets for GRC Standards

**Status:** Draft • **Version:** v0 • **Target chain:** gno.land

---

## Abstract

This lite paper introduces the concept of **append-only Petri-net logic** for Governance Realm Contracts (GRCs). 
Append-only semantics offer a path to upgrade on-chain models while preserving determinism, reproducibility, and composability. 
By extending nets through additions only — without mutation of existing rules — we achieve a rare balance between *immutability* and *evolution*.

---

## 1. Introduction

Blockchain systems prize immutability for auditability, yet real-world applications demand adaptability. 
Traditional smart contract upgrade methods often involve risky migrations or proxy patterns, which may undermine trust.

Append-only Petri-net logic offers a different approach: extend system behavior by **adding new transitions and arcs** without altering existing ones. 
This method aligns with the minimal, composable philosophy behind GRC token standards and similar primitives.

---

## 2. The Mutability Paradox

In on-chain environments, developers face two competing needs:
- **Immutability**: Guarantees that past behavior remains verifiable and unaltered.
- **Mutability**: Enables systems to adapt, fix bugs, and add features.

Append-only Petri-net updates solve this paradox by ensuring:
- History is preserved in full.
- New behavior is layered onto existing structures.

This mirrors a "Git commit" workflow, where each upgrade is a new commit without rebasing history.

---

## 3. Benefits of Append-Only Nets

### 3.1 Reproducibility
Every marking and transition firing from genesis can be replayed deterministically. 
Developers and auditors can:
- Verify the current state by replaying history.
- Fork the model from any historical point with confidence.

### 3.2 Composable Upgrades
Petri nets act as **primitives** in larger compositions. Append-only upgrades mean:
- Subnets can evolve without breaking existing compositions.
- Dependent modules can rely on a stable base.

### 3.3 Alignment with GRC Philosophy
Where ERC-20 upgrades often risk breaking integrations, GRC + append-only nets provide:
- Predictable upgrade semantics.
- Backward compatibility by design.

### 3.4 Easier Formal Verification
- Old invariants remain true for preserved portions of the net.
- Verification focuses on the delta introduced by new transitions.

---

## 4. Use Cases

- **Token Standards**: Evolving GRC fungible token logic safely.
- **DAO Governance**: Adding new voting mechanics without invalidating past decisions.
- **DeFi Protocols**: Layering new liquidity rules without disrupting existing market flows.

---

## 5. Conclusion

Append-only Petri-net logic offers a practical upgrade path for GRCs that balances the permanence of blockchain with the flexibility of evolving systems. 
By ensuring that updates are strictly additive, we protect trust, maintain reproducibility, and enable safe composability.
