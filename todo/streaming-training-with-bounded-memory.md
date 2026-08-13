# Training over many apples must not grow the graph

## Why it matters

`updateModel` folds over `Training = [Observation]` and keeps a fixed-size `Model` no matter how
many apples it has seen — that is what conjugacy buys. The graph version does not have that property
for free: every observed apple is a **new node**, and

```haskell
data Graph = Graph { nodes :: IntMap SomeNode, maxKey :: Int }
```

only ever grows. `realize` writes a `Realized a` node in place and, as
[references to a realized node](references-to-realized-nodes-are-inconsistent.md) records, does not
sever the parent edge; `deallocateRealized` removes the node but must be called explicitly. So a
training run over *n* apples leaves *n* dead nodes in the map unless the caller cleans up — and
because `lookupChildren` scans every node
([no child index](graph-has-no-child-index.md)), those dead nodes make every subsequent operation
slower. The result is quadratic.

This is not hypothetical: it is the reason both Markov-chain tests in
`delayed-sampling/test/DelayedSampling.hs` call `deallocateRealized` by hand after each step. A
performance workaround is currently part of the expected usage of the API, and the apple model is
exactly the same access pattern — one observed leaf per datum, hanging off a small set of
long-lived parameter nodes — so it inherits the same problem at the same scale.

The apple case is in one respect *worse* and in another *better* than the Markov chain. Worse: the
parameter nodes are long-lived and shared across all cultivars under a hierarchical prior, so the
graph never fully drains and there is always a live node with many realized children. Better: the
observations are conditionally independent given the parameters rather than forming a chain, so
there is no growing dependency *path*.

The invariant to aim at is therefore **the graph grows with the number of entities, never with the
number of observations** — not "the graph returns to the size it had before", which is only true of a
flat one-prior-per-cultivar model. This is **R11**, and it has a second half in **R10**: each new tree
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
  into its children and drops the node. That fix is described in
  [references to a realized node](references-to-realized-nodes-are-inconsistent.md) and is cheap
  only with the [child index](graph-has-no-child-index.md); this item is mostly a statement of *why*
  those two matter for the apple model rather than a third piece of work.
- A test that folds *n* observations through a fixed set of parameter nodes and asserts
  `IntMap.size . nodes` is constant in *n*, and that the wall-clock cost is linear — the existing
  tests demonstrate the workaround rather than the property.
- Ideally `maxKey` reuse or wraparound is considered too: it is a monotone `Int` counter, so a
  genuinely long-running training process leaks index space even if nodes are freed. At `Int` width
  this is theoretical, but it is the kind of thing that decides whether "streaming" means "a long
  batch" or "a process that runs for months".
