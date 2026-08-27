---
status: closed
pkg: [delayed-sampling]
provenance: "Restored from history after being closed by file deletion; the deleting commit's parent, 5550a50, holds this file's last live content, byte-identical here."
closed_by: "8ded243 Fix the local defects found while porting delayed-sampling"
---
# Graph invariants are never checked

## Why it matters

The paper's correctness argument rests on two invariants over the node states
*initialized* (I) / *marginalized* (M) / *realized* (R):

- **Invariant 1** — if a node is in M, then its parent is in M.
- **Invariant 2** — a node has at most one child in M.

Neither is checked anywhere in `Control.Monad.Bayes.DelayedSampling`.

- Invariant 1: the `Error` type has a constructor `ParentNotMarginalised` carrying the FIXME
  *"need to implement check for that"*. **Nothing constructs it.**
- Invariant 2: no check exists at all. `graft` compensates defensively — it prunes *every*
  marginalized child it finds via `lookupChildren`, rather than relying on there being at
  most one. That masks a violation instead of detecting it, and it is the reason `graft`
  cannot be made cheap without also establishing the invariant.
- The single check that does exist, `atMostOneParent`, tests the *forest* property (≤1 parent
  per node) — which is a third, separate requirement, not Invariant 1 or 2. It is reachable
  only through `ensureConsistency`, and **`ensureConsistency` has no call sites**; its own
  FIXME reads *"use regularly, at least in tests"*. So even the forest check never runs,
  which is precisely why the bug in its predicate went unnoticed
  (see [at-most-one-parent-misses-expression-parents.md](at-most-one-parent-misses-expression-parents.md)).

The practical consequence is that every invariant violation surfaces later as a confusing
downstream failure — `NotMarginal` from `pdf`, or a silently wrong marginal — instead of at
the operation that broke it.

## Done when

- `ensureConsistency` checks all three properties: forest, Invariant 1, Invariant 2, with a
  distinct `Error` for each (reusing `ParentNotMarginalised`, adding one for Invariant 2).
- It is called from the test suite after every `graft` / `marginalize` / `realize` /
  `observe`, so the existing acceptance tests double as invariant tests. Calling it in
  library code on every operation is O(|graph|) and must stay opt-in (debug-only) until the
  graph carries an explicit child index.
- `graft` relies on Invariant 2 (prune *the* marginalized child) instead of scanning for all
  of them.
