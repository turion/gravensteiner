# `Graph` has no child index, so every graph operation scans every node

## Why it matters

The paper's graph has explicit edges in both directions; `Graph` stores only
`nodes :: IntMap SomeNode`, and parenthood is *derived* by reading `getParents` off each
node's `initialDistribution`. There is no way to go from a node to its children except by
walking the whole map, which is exactly what `lookupChildren` does:

```haskell
lookupChildren var = do
  nodes <- DelayedSamplingT $ lift $ gets nodes
  pure $ map (uncurry unsafeResolvedVariable) $ filter ((SomeVariable var `elem`) . getParentsSome . snd) $ IntMap.toAscList nodes
```

`lookupChildren` is called by `lookupTerminal`, `realize`, `graft` and `prune` — i.e. by
every operation that does anything — so all of them are O(|graph|) rather than
O(number of children). `deallocateRealized` is likewise O(|graph|), by
`IntMap.map (substSome var a)` over all nodes; its own FIXME says "this should be linear in
the variable".

Consequences, in increasing order of importance:

- The 10 000-observation Markov-chain test is quadratic unless the caller deallocates each
  realized node by hand, which is why both Markov tests do. That makes a performance
  workaround part of the public API's expected usage.
- `ensureConsistency` is worse than linear for the same reason: `marginalizedChildren`
  computes the marginalized children of every node by scanning every node, so it is
  O(|graph|²). That is why it is called from the test suite only, and why it cannot be turned
  on inside library code as a debug assertion.
- `graft` and `prune` cannot exploit Invariant 2 — they loop over all marginalized children
  because finding "the" one costs the same scan. See
  [`graft` and `prune` scan for all marginalized children](graft-does-not-use-invariant-2.md).
- Inlining a realized value into its children, which is the fix for
  [the inconsistent handling of realized nodes](references-to-realized-nodes-are-inconsistent.md), is only cheap
  with a child index.

## Done when

`Graph` carries the child relation explicitly — `children :: IntMap IntSet` alongside
`nodes`, or a child set per node — maintained by `initialize` (which already computes
`getParents initialDistribution`), by `realize`/`deallocateRealized` on removal, and by
whatever substitution ends up dropping edges (`scale 0` already can). `lookupChildren` reads
it directly, `ensureConsistency` becomes O(|graph|), and the Markov-chain tests no longer
need a manual `deallocateRealized`.

Worth deciding at the same time whether the derived-parent representation should stay at all:
keeping edges in `initialDistribution` *and* in an index means two sources of truth that can
disagree, and `atMostOneParent` exists precisely to catch one class of disagreement. The
alternative is to store the parent (or supernode) on the node and treat the expression as
payload.
