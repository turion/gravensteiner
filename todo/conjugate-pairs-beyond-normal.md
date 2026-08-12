# Only `Normal` is usable, and only the normal-normal conjugate pair delays

## Why it matters

Conjugate priors are one of the paper's two core ingredients (the other being affine
transformation). `Distribution` has exactly three constructors —

```haskell
  Normal  :: Value Double -> Value Double -> Distribution Double
  Normal2 :: Value (Double, Double) -> Distribution Double
  Beta    :: Value Double -> Value Double -> Distribution Double
```

— and support for them is ragged, in three tiers that are separate extension points:

| Tier | Enforced by | Currently |
|---|---|---|
| exists as a root and can be sampled | `sampleMarginal` | `Normal`, `Beta` |
| can be `observe`d | `pdf` | `Normal` only — `pdf (Beta _alpha _beta) = throw NotImplemented` |
| can delay: have a child, be conditioned by one | `marginalizeDistribution`, `conditionDist` | normal-normal only |

`Beta` illustrates how little the lower tiers buy. It can be created as a root and sampled, and
nothing else: it cannot be observed, cannot have a child, and cannot be conditioned. It
contributes no delay whatsoever, which makes its presence misleading rather than useful — a model
author reads the constructor list as a menu.

**There is no `Gamma` constructor at all**, nor anything discrete: no Bernoulli, binomial,
categorical, Poisson, exponential or Dirichlet. That is a tier-0 gap, and a harder one than it
looks, because a distribution that is missing entirely cannot even be *transcribed* into the
graph as an immediately-sampled root — whereas `Beta` at least occupies the right shape for
someone to fill in later.

Beta and gamma are confirmed requirements, not speculative ones: the apple model already samples
Gamma(1,1) by hand in `sampleDirichletColours`, and per-observer reliability wants a Beta.

## The pairs worth having

Grouped in one file deliberately — each needs the same extension points and has the same "done"
criterion, so near-identical files per pair would only repeat this table.

| Pair | Unlocks | Extra machinery beyond the tiers above |
|---|---|---|
| beta-Bernoulli / beta-binomial | the existing `Beta` becoming real; per-observer reliability in the apple model | a discrete child, hence exact enumeration rather than sampling |
| gamma-Poisson, gamma-exponential | count and waiting-time data, with the gamma as a conjugate prior on a rate | a `Gamma` constructor; a discrete child for the Poisson case |
| normal-gamma / normal-inverse-gamma | unknown mean *and* variance for a normal — the standard next step for the existing normal machinery | a `Gamma` constructor, plus a variance that is itself a variable, which the current `Normal` shape forbids |
| Dirichlet-categorical / Dirichlet-multinomial | the apple model's colour simplex and cultivar identity | vector-valued variables |

Two cautions about how this interacts with the rest of the backlog.

**Gamma has two unrelated jobs, and only one of them delays.** As a conjugate prior on a rate or
a precision it is a genuine delayed-sampling win. As a hyperprior on a Dirichlet's *concentration
parameters* — which is what the apple model reaches for — it is not conjugate to anything and has
no closed-form normalizer, so no amount of delayed sampling rescues it; that use has to be
sampled. Implementing `Gamma` therefore does not by itself unblock the apple model, and the two
uses should not be conflated when scoping the work.

**Discrete latents want enumeration, not sampling.** A categorical or Bernoulli latent is usually
better marginalized *exactly* — the posterior over cultivars is the answer the apple model is
asking for — which is delayed sampling composed with an enumeration monad rather than a conjugate
update. That is a separate design question, recorded with the apple model's gaps.

**Normal-gamma collides with the constancy requirement** on `Normal`'s variance described in
[the marginal/conditional distinction](no-type-level-marginal-conditional.md): making the variance
a variable is exactly what that item's second axis forbids, so the two must be designed together.

## Done when

For each pair: a `Distribution` constructor; clauses in `pdf`, `sampleMarginal`,
`marginalizeDistribution` and `conditionDist`; and a statistical acceptance test in the style of
the existing ones — many observations from a known truth, asserting the posterior recovers it
within a stated tolerance. Type-correctness is not evidence here; the two statistical tests are
what actually establish that the normal-normal updates are right.

Also: `pdf (Beta …) = throw NotImplemented` should either become a real density or the constructor
should go, so that the set of usable distributions is visible from the type rather than discovered
at runtime. Better still, the three tiers should be visible too — see
[`pdf`'s catch-all hides unimplemented distributions](pdf-catch-all-hides-unimplemented.md), which
is the same defect from the error-reporting side.
