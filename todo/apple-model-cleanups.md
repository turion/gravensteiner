# Findings from `Main.hs` that outlive it

> **Cut down to what transfers.** `gravensteiner/app/Main.hs` is a precursor superseded by
> `Gravensteiner.Model` plus [the network design](model-v1-bayesian-network.md), so it is being
> deleted rather than fixed. What was removed from this file with it: the `identify` faults (now
> R13 and Tier 2 of [the review](model-v1-review.md)), the `MonadIO`-forcing debug output, the dead
> and duplicated declarations, and the `Dirichlet` hyperprior. What remains below is the two findings
> that apply unchanged to code that is not being deleted. The third — no test suite and no way to
> tell whether the model works — has moved to
> [no evaluation harness](no-evaluation-harness.md), because it is a live gap about the *new* model
> rather than a cleanup of the old one.

## The refinement newtypes do not refine anything

This is the finding that transfers most directly, because `Gravensteiner.Model`'s `Interval` repeats
it exactly:

```haskell
newtype Interval = Interval {getInterval :: Double}
  deriving (Show, Eq, Ord, Num, Fractional, Floating)
```

`Interval 0.9 + Interval 0.9` is `Interval 1.8`; `exp (Interval 0.5)` leaves the unit interval. A
type whose entire point is a constraint must not derive a class whose operations do not preserve it —
the same lesson as [drop `Num` for affine combinators](drop-num-for-affine-combinators.md), which is
that item's own subject one level down. The old version had smart constructors that were never
called; the new one has **no smart constructor at all**, so nothing is checked anywhere.

Two details worth keeping because they show what "expose the operations that preserve it" buys. The
old `nonnegative` was `guard (i > 0)`, character-for-character the same function as `positive`, so
`Nonnegative 0` could not be built through the intended door while `frequency = 0` was set through
the other one. And `updateDirichletColours` asked
`-- FIXME Is the nonnegative property satisfied? Can I prove it on the type level?` — to which the
answer was yes: for *x* ∈ (0, 1], −ln *x* ≥ 0, so `negLog :: Interval -> Nonnegative` plus
`addNonneg :: Nonnegative -> Nonnegative -> Nonnegative` makes the update nonnegativity-preserving
by construction. As written, the intermediate value was a *negative* `Nonnegative`, so the invariant
was violated mid-expression and restored by accident. Two combinators removed both the doubt and the
FIXME.

Re-flagged in Tier 3 of [the review](model-v1-review.md) so the finding is visible from the v1 side
too.

## Numerics: leave log space only at the end

A general principle, and the new model has more densities, not fewer, so it matters more rather than
less.

The old `beta as = exp $ sum (logGamma <$> as) - logGamma (sum as)` computed in log space and then
exponentiated, and both call sites immediately took the log again. Each round trip can leave the
range of `Double`, and the failure was **underflow, not overflow**: `ln B(α)` is large and negative
for large concentrations, so `exp` returned 0 below about −745 and the subsequent division yielded
`Infinity`. The trigger was the number of *training observations* rather than the concentrations
themselves, since each apple grew every component of the hyperparameter — so it was a bug that
appeared only after a few hundred apples, which is the worst kind to find in production.

The rule that avoids it: keep densities in `Log Double` end to end and never call `exp` on an
intermediate. `Numeric.SpecFunctions` supplies `logGamma`, so a `logBeta` that never leaves log space
is a one-line change wherever this shape recurs.

## Done when

`Interval` (and any sibling refinement type in `Gravensteiner.Model`) enforces its invariant by
construction rather than deriving it away, and every density in the new model is computed in
`Log Double` throughout.
