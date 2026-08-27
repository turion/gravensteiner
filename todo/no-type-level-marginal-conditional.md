---
status: open
milestone: [6]
size: M
size_evidence: "no cue in source file"
pkg: [delayed-sampling]
---
# Marginal and conditional distributions are not distinguished in the type

## Why it matters

The module's own FIXME on `Node` states the invariant:

> If I understand it correctly, marginal distributions never have dependencies on variables.
> If that is right, there ought to be a type tag in `Distribution` saying which kind of values
> can occur […]

The understanding is right, and the tag is missing, so the distinction is enforced by pattern
matching plus a runtime error in five places:

| Function | Matches | Otherwise |
|---|---|---|
| `pdf` | `Normal (Const _) (Const _)` | `throw NotMarginal` |
| `sampleMarginal` | `Normal (Const _) (Const _)`, `Beta (Const _) (Const _)` | `throw NotMarginal` |
| `isTerminalDistribution` | the same two shapes | `False` |
| `marginalizeDistribution` | parent must be `Normal (Const _) (Const _)` | `UnsupportedConditioning` |
| `conditionDist` | parent must be `Normal (Const _) (Const _)` | `UnsupportedConditioning` |

`Node`'s `marginalDistribution :: Maybe (Distribution a)` has the same problem one level up:
the three states of the paper (*I*, *M*, *R*) are encoded as a constructor plus a `Maybe`, so
"is marginalized" is a runtime question. `isMarginalized`, `isRealized`, `requireMarginalized`
and the `NotMarginal` error all exist only to answer it, and `requireMarginalized`'s own
haddock has to explain that its error is unreachable.

There are actually **two independent axes** here, which is worth getting right before
implementing:

1. **Constancy of a `Value`.** A marginal distribution's parameters mention no variables.
2. **Constancy required regardless of phase.** Normal-normal conjugacy needs the *variance* to
   be a constant even in an initial distribution — `Normal :: Value Double -> Value Double ->
   Distribution Double` allows `normalDS (Var a) (Var a)`, which type-checks and passes
   `ensureConsistency`, yet every inference function rejects it. The test "accepts a node that
   refers to the same parent twice" only passes because it calls nothing but
   `ensureConsistency`.

So the mean position wants "affine in phase *I*, constant in phase *M*" and the variance wants
"constant always". A single phase index does not express the second; a constancy index on
`Value` does both, and is the same machinery
[dropping `Num`](drop-num-for-affine-combinators.md) would want.

## Done when

`Distribution` (and `Node`) are indexed so that:

- `pdf` and `sampleMarginal` are total, with no `NotMarginal` case,
- `isTerminalDistribution` and `requireMarginalized` are unnecessary,
- `marginalize` returns a marginal distribution *by type*, so `setMarginalized` cannot be
  handed a conditional one,
- `Normal`'s variance parameter cannot be a variable,
- the `NotMarginal` constructor is gone from `Error` (currently seven use sites).

Related: [`pdf`'s catch-all hides unimplemented distributions](pdf-catch-all-hides-unimplemented.md)
is the same defect seen from the error-reporting side — `pdf`'s fall-through reports
`NotMarginal` for a `Normal2`, which is not marginality at all but an unimplemented
distribution.
