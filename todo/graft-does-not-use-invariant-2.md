# `graft` and `prune` scan for all marginalized children

> **Update:** `Graph` now carries a child index (`children :: IntMap IntSet`), so `lookupChildren`
> is no longer a full scan — but `graft` and `prune` still loop over every marginalized child they
> find via `forM_`, rather than fetching *the* one Invariant 2 guarantees and erroring on a second.
> The performance argument below is resolved; the diagnosis argument is not.

## Why it matters

Invariant 2 of the paper says a node has at most one child in *M*. `ensureConsistency`
now checks it, and the test suite calls it after every graph-changing operation, so the
invariant is established rather than hoped for.

`graft` and `prune` do not use it. Both call `lookupChildren` and then loop over *every*
marginalized child they find, pruning each. `marginalizedChildren` (used by `ensureConsistency`)
already computes the single-child-or-error shape that `graft`/`prune` want but do not use.

A second marginalized child is silently absorbed by the loop instead of
being reported. The invariant now has a check, but the operations that depend on it
still behave as if it might not hold, so a violation introduced by future work would
show up as a wrong marginal rather than as `MultipleMarginalizedChildren`.

## Done when

`graft` and `prune` look up the single marginalized child through `marginalizedChildren` (or
equivalent), and treat a second one as an error rather than pruning it too.
