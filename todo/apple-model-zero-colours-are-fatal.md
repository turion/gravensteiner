---
status: closed
pkg: [gravensteiner]
closed_by: "c774c60 todo: observation model v1 review, network design, and requirements"
---
# Exact zeros in the colour proportions make every density NaN or infinite

> **Resolved by design; kept as the diagnosis.** The v1 schema drops the composition entirely
> (ground colour and overcolour are independent coordinates, russet is separate), so there is no
> simplex left to have a boundary and no colour can be a structural zero. The only zero-inflated
> coordinate is russet extent, and its presence indicator is *observed* — the observer records
> whether there is any russet at all — so it contributes a Bernoulli likelihood and **no latent
> variable**. The crash analysis below still stands as the reason the old `Main.hs` executable
> exits with `categorical: bad weights!`, and as the worked example of why a boundary-of-support
> value is a modelling error rather than a numerical one. See
> [the network design](model-v1-bayesian-network.md).

## Why it matters

This is not a subtle statistical objection — it is why the executable dies. Every entry of
`initialTraining` has exact zeros: `Observation "Jonathan" $ Apple {colours = Just $ noColours
{red = 0.9, yellow = 0.1}}` leaves green and brown at 0, because `noColours` sets all four to 0
and each observation overrides only the colours it mentions.

**In the hyperprior update.** `updateDirichletColours` computes
`greenPrior - Nonnegative (log $ getInterval green)` — with `green = 0` that is
`-log 0.1 - (-Infinity)` = `+Infinity`. So after a single training apple, two of the four
`DirichletColoursPrior` components are infinite.

**In the hyperprior density.** `dirichletColoursLikelihood` then evaluates
`Exp (negate $ sum ...)` over terms `greenPrior * greenDirichlet` = ∞, giving `Exp (-Infinity)` —
i.e. 0 — in the numerator, and in the denominator `beta [finite, finite, ∞, ∞]`, which is
`exp (sum (logGamma <$> as) - logGamma (sum as))` = `exp (∞ - ∞)` = `NaN`. The quotient is `NaN`.
`sampleDirichletColours` hands those weights to `proper . fromWeightedList`, which is exactly the
`System.Random.MWC.Distributions.categorical: bad weights!` the executable currently exits with.

**In the likelihood, independently.** `coloursLikelihood` computes
`getInterval green ** (getNonnegative greenDirichlet - 1)`, i.e. `0 ** (α - 1)`: `+Infinity` for
α < 1 and `0` for α > 1. `sampleDirichletColours` proposes α ~ Gamma(1, 1), so α < 1 with
probability 1 − e⁻¹ ≈ 0.63. Even with the hyperprior fixed, `identify` on the query apple
(`red = 0.9, yellow = 0.1`) is singular.

The underlying fact is structural, not numerical: **the Dirichlet's support is the *open* simplex.**
A composition with a component of exactly 0 is not an unlikely observation to be handled with care,
it is outside the support, and no amount of floating-point hygiene fixes that. Real apples really
do have zero russet, so this is a modelling error, not a data-entry error.

And the deeper reason the zeros are there at all is that `brown` is not a colour:
[russet is a texture](russet-is-not-a-colour.md), it does not partition the surface with the
pigments, and most cultivars have none of it. So the field that produces the fatal zeros is
precisely the one that never belonged in the composition — which both explains the bug and points at
the fix.

## What survives, and what does not

**Done — by deletion of the premise.** The composition is gone, so there is no boundary of support to
land on. Only russet extent is zero-inflated, its presence indicator is observed, and ground colour
needs no presence layer at all, being a position rather than a coverage. The per-option fixes that
this section used to list (regularising the observations, or a Dirichlet-multinomial that tolerates
zeros) are all moot; see [the reformulation options](apple-model-reformulation-options.md).

Two things are worth carrying forward rather than closing:

- **The general lesson.** A value on the boundary of a distribution's support is a *modelling* error,
  not a numerical one, and no amount of floating-point hygiene fixes it. The question to ask of any
  new feature is what its structural zeros are and whether the chosen family admits them — which is
  why the appearance vector states its transform per coordinate.
- **The class of test this needs.** "Every weight reaching a resampling step is finite and
  non-negative" is a property worth asserting over the whole seed corpus, not just over three
  hand-written apples, and there is still no `test-suite` to put it in — see
  [no evaluation harness](no-evaluation-harness.md).
