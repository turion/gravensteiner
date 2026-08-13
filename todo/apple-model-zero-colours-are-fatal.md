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

## Done when

The fix depends on the choice made in
[the reformulation options](apple-model-reformulation-options.md), and each option answers it
differently:

- **Counts / Dirichlet-multinomial (A):** nothing to do. *n*_green = 0 is an ordinary multinomial
  outcome with positive probability. This is a strong argument for A.
- **Logistic-normal (B), the chosen option:** logit(0) = −∞ too, so B needs the structural-zero
  layer — a presence indicator (Bernoulli, Beta prior) on the zero-inflated quantities, with a
  logit-normal over the extent when present. B does not get this for free, but under the corrected
  appearance scheme only russet extent is genuinely zero-inflated, and ground colour needs no layer
  at all, being a position rather than a coverage.
- **Status quo (C):** the observations must be regularised, e.g. *x* ← (1 − ε)·*x* + ε/4 with a
  stated ε, or `Interval`'s smart constructor tightened to the open interval so a 0 cannot be
  built. Regularisation is a fudge — it asserts every apple is slightly brown — but it is what the
  current model needs in order to run at all.

Independently of the choice:

- A test that folding `initialTraining` through `updateModel` leaves every `DirichletColoursPrior`
  component finite, and that every weight reaching `proper` is finite and non-negative. There is
  no test suite for `gravensteiner` at all right now.
- `dirichletColoursNormalizable` belongs in that test suite rather than in `main` — its own FIXME
  says so. Note that `main` checks only `initialSortColours`: the condition that matters is that
  Σₖ exp(−*v*ₖ/η) < 1 still holds *after every update*, and since an update raises both *v*ₖ and
  η the condition is not monotone, so checking the initial value alone proves nothing.
