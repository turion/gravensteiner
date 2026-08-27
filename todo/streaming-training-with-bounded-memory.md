---
status: open
milestone: [6]
size: M
size_evidence: "no cue in source file"
pkg: [delayed-sampling]
---
# Training over many apples must not grow the graph

> **Update:** the two prerequisites this item leaned on are both done — `Graph` now carries a
> child index (`children :: IntMap IntSet`) and `graft`'s realized case is `pure ()` rather than a
> throw, with the manual `deallocateRealized` calls already removed from both Markov-chain tests
> (see `delayed-sampling/test/DelayedSampling.hs`). What is still open is the finding below: nothing
> yet makes `realize` inline the value and drop the node, so a training run over many apples still
> grows the graph by one dead node per observation, just cheaply rather than quadratically.

## Why it matters

`updateModel` folds over `Training = [Observation]` and keeps a fixed-size `Model` no matter how
many apples it has seen — that is what conjugacy buys. The graph version does not have that property
for free: every observed apple is a **new node**, and

```haskell
data Graph = Graph { nodes :: IntMap SomeNode, maxKey :: Int }
```

only ever grows.

`realize` writes a `Realized a` node in place and does not sever the parent edge;
`deallocateRealized` removes the node but must be called explicitly. So a training run over *n*
apples leaves *n* dead nodes in the map unless the caller cleans up. With the child index this no
longer makes every subsequent operation slower, but the graph still only grows.

A performance workaround (manual `deallocateRealized`) was part of the expected usage of the API
until recently; the apple model is exactly the same access pattern — one observed leaf per datum,
hanging off a small set of long-lived parameter nodes — so it inherits the same growth problem.

The apple case is in one respect *worse* and in another *better* than the Markov chain. Worse: the
parameter nodes are long-lived and shared across all cultivars under a hierarchical prior, so the
graph never fully drains and there is always a live node with many realized children. Better: the
observations are conditionally independent given the parameters rather than forming a chain, so
there is no growing dependency *path*.

The invariant to aim at is therefore **the graph grows with the number of entities, never with the
number of observations** — not "the graph returns to the size it had before", which is only true of a
flat one-prior-per-cultivar model. Both halves matter: each new tree
and observer adds a *permanent* latent that later fruit will need, so a fitted state must be
*extensible*, not merely reusable. [The network design](model-v1-bayesian-network.md) puts numbers on
the split — fruit and collections grow without bound (10⁴–10⁵), while cultivars, regions and source
classes do not and trees and observers grow slowly (10³) — and that split is the reason bounded-memory
inference is possible at all.

Both halves need testing, since the failure modes differ and look alike: observations leaking nodes is
the bug above, whereas entity latents accumulating is correct and must not be "fixed".

## Done when

- Observing and absorbing one datum leaves the graph at its previous size, without the caller
  calling `deallocateRealized` — which means `realize` (or `observe`) inlines the realized value
  into its children and drops the node, now that the child index makes that cheap.
- A test that folds *n* observations through a fixed set of parameter nodes and asserts
  `IntMap.size . nodes` is constant in *n*, and that the wall-clock cost is linear — the existing
  tests demonstrate the workaround rather than the property.
- Ideally `maxKey` reuse or wraparound is considered too: it is a monotone `Int` counter, so a
  genuinely long-running training process leaks index space even if nodes are freed. At `Int` width
  this is theoretical, but it is the kind of thing that decides whether "streaming" means "a long
  batch" or "a process that runs for months".

## From the v1 requirements document (R10)

This is the practical form of the same point. Hundreds of collections a year means the system must
extend a fitted state rather than refit, and — because trees and observers are new entities —
extension has to grow the latent vector, not just condition on it. In information form that is
cheap (a new entity is a new diagonal block plus a few off-diagonal entries), which is a second
argument for
[no supernodes for multiple parents](no-supernodes-for-multiple-parents.md)'s sparse-precision
representation.

## From the v1 requirements document (R11)

| # | Requirement | Needed for | Status |
|---|---|---|---|
| R11 | Bounded memory: fruit transient, entities permanent | 10⁵ fruit, 10³ entities | [streaming](streaming-training-with-bounded-memory.md) |
