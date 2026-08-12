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
observations are i.i.d. given the parameters rather than a chain, so there is no growing
dependency path — after each apple is absorbed, the graph should return to exactly the size it had
before. That "returns to its previous size" property is a crisp, testable invariant, and it is the
right acceptance criterion.

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
