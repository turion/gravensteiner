# `graft` and `prune` scan for all marginalized children

## Why it matters

Invariant 2 of the paper says a node has at most one child in *M*. `ensureConsistency`
now checks it, and the test suite calls it after every graph-changing operation, so the
invariant is established rather than hoped for.

`graft` and `prune` do not use it. Both call `lookupChildren` — which walks the entire
`IntMap` of nodes, since `Graph` has no child index — and then loop over *every*
marginalized child they find, pruning each. Two costs:

- **Performance.** The scan makes `graft` and `prune` O(|graph|). With Invariant 2 in
  hand, both want to fetch *the* marginalized child directly. This is the same missing
  child index that forces the Markov-chain tests to call `deallocateRealized` by hand
  after every observation.
- **Diagnosis.** A second marginalized child is silently absorbed by the loop instead of
  being reported. The invariant now has a check, but the operations that depend on it
  still behave as if it might not hold, so a violation introduced by future work would
  show up as a wrong marginal rather than as `MultipleMarginalizedChildren`.

## Done when

`Graph` carries an explicit child index; `graft` and `prune` look up the single
marginalized child through it, and treat a second one as an error rather than pruning it
too.
