---
status: closed
pkg: [delayed-sampling]
provenance: "Restored from history after being closed by file deletion; the deleting commit's parent, 5550a50, holds this file's last live content, byte-identical here."
closed_by: "8ded243 Fix the local defects found while porting delayed-sampling"
---
# `atMostOneParent` misses every expression-shaped parent

## Why it matters

The paper requires the graph to be a **forest**: at most one parent per node. Multi-parent
nodes need supernodes ("much like the junction tree algorithm"), which are not implemented.
`atMostOneParent` exists to catch violations, but its predicate
`atMostOneParentDistribution` matches only two shapes:

    Normal (Var _) (Var _)
    Beta  (Var _) (Var _)

and returns `Nothing` — i.e. "fine" — for everything else. Every multi-parent case that can
actually arise is built from the `Value` expression constructors `Sum` and `Product`, not from
two bare `Var`s: `Var posVar + Const t * Var velVar` in the commented-out Kalman test is
`Sum posVar (Product t velVar)`, which the predicate waves through.

It also gets the trivial case wrong in the other direction: `Normal (Var x) (Var x)` is two
edges to a *single* parent, and would be reported as a violation.

## Done when

The predicate is derived from `getParents`, which already computes exactly the right answer
for all `Value` shapes:

    atMostOneParentDistribution d = case nubBy sameVariable (getParents d) of
      ps@(_ : _ : _) -> Just ps
      _              -> Nothing

with deduplication by the underlying `Variable` index, so repeated references to one parent
are not flagged. This makes the special-casing per `Distribution` constructor disappear, so
new distributions are covered automatically.

Note this check is currently unreachable — see
[invariants-unchecked.md](invariants-unchecked.md). Fixing the predicate is only useful
together with calling `ensureConsistency`.
