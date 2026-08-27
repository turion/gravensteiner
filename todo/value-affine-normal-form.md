---
status: open
milestone: [6]
size: M
size_evidence: "no cue in source file"
pkg: [delayed-sampling]
parent: model-v1-bayesian-network
---
# `Value` has no affine normal form

## Why it matters

Affine transformation is one of the paper's two core ingredients (the other being
conjugate priors), and `Value` is where it lives. The fix pass on the port made `Sum` and
`Product` closed under the affine operations, gave them the constant-folding smart
constructors `plus` and `scale`, made `Num`/`Fractional`/`subst` total on the affine
subset, and removed the `unsafeCoerce` uses. It left the representation unnormalized, and
it left the non-affine operations as runtime errors — the latter is
[its own item](drop-num-for-affine-combinators.md).

`Value` is an unnormalized expression tree: the same affine function has many spellings,
and `Sum` can nest arbitrarily. `marginalizeDistribution` and `conditionDist` pattern-match
on the two spellings they support — `Normal (Var v) (Const _)` and
`Normal (Product c (Var v)) (Const _)` — and throw `UnsupportedConditioning` for everything
else, including every `Sum`, i.e. every multi-parent expression. `isTerminalDistribution`
likewise recognises only fully folded constants.

Replacing the two constructors with a normalized linear combination (a map from variable
index to coefficient, plus an offset) would let those functions match on structure instead:
one clause for "affine in the parent", with the coefficient read off the map. It also makes
`getParents` exact by construction, collapses `Var x + Var x` into `2 · x` so that repeated
mentions of one parent become supportable, and is a prerequisite for supernodes /
multi-parent support and for the apple model's derived observations.

## Also

`substVar` returns `Nothing` when a variable index matches but the type does not, so the
substitution is silently skipped. That situation cannot arise in a well-formed graph —
`onNode` reports it as `TypesInconsistent` — but the silence is a latent trap; it becomes
cheap to report once `Graph` tracks the type of each node.

## From the v1 requirements document (R2)

This is the mechanical part. The fruit mean is a sum of six latent vectors plus two
observed-coefficient regression terms, so `Value` must express `sum_j (c_j *^ Var v_j) + const`
with `c_j` known scalars and `v_j` vector-valued. [The affine normal form](value-affine-normal-form.md)
proposes exactly this normal form for the scalar case; the generalisation is that the coefficients
become scalars against vector variables, and later matrices. Nothing about it is conceptually hard
and it should be done first, because [the multivariate-normal vector node](vector-valued-variables-and-dirichlet.md)
and [the sparse precision representation](no-supernodes-for-multiple-parents.md) both consume it.
