---
status: closed
pkg: [gravensteiner]
closed_by: "f02577d todo: straighten the backlog into one coherent, sorted plan"
---
# The likelihood question, and the decision it reached

> **Decided; kept as the decision record.** This file was three open questions — what a colour
> observation *is*, what carries the per-cultivar parameters, and what `identify` returns. All three
> are now answered, so the file has been cut down to the answers and the reasoning that survives
> them. What was removed: the mechanics of options A and C (Dirichlet-multinomial counts, and
> repairing the `Main.hs` importance sampler), and a "port at reduced fidelity today" sketch built
> on an alr transform that the chosen parameterisation does not use — the still-valid version of
> that sketch was *What is already supported today* in the deleted requirements document: a scalar
> version of the model is implementable now with `conditionDist`'s existing clauses.

## The question, and the trade-off it turned on

`gravensteiner/app/Main.hs` did its conjugate update **by hand**: `updateDirichletColours` was the
update, `updateModel` folded it over the training set, and no inference monad appeared outside
`identify`. The middle level of that model was the [conjugate prior of the
Dirichlet](https://en.wikipedia.org/wiki/Dirichlet_distribution#Conjugate_prior_of_the_Dirichlet_distribution),
which has **no closed-form normalizer** — the entire reason `sampleDirichletColours` and its
ten-sample importance sampler existed. Porting was therefore always going to be a rewrite, and the
rewrite was the moment to change the model.

The choice was between two families, and stated once it is the whole question:

> **Dirichlet-multinomial is robust to zeros and needs no hyperprior, but its parameters cannot be
> an affine function of anything. Logistic-normal absorbs covariates and latents affinely but is
> undefined at zero.**

## The decision: option B, on a transformed scale, with no composition left

**Option B — normal on an unconstrained scale — is chosen**, and two later findings made the choice
easy rather than close. [Russet is a texture, not a colour](russet-is-not-a-colour.md), so the four
numbers were never a composition and there is no simplex to model; and every planned covariate
(ripening duration, tree, year, observer bias) enters **affinely**, which is exactly what B supports
and A cannot. With the composition gone, the alr transform goes too: there is no log-ratio anywhere
in the result.

The concrete parameterisation is settled — ground-colour position on a green→yellow axis, overcolour
extent as a fraction of non-russeted skin, an overcolour pattern categorical, and russet extent, the
only genuinely zero-inflated coordinate, whose presence indicator is *observed* and therefore costs
no latent variable. See [the chosen appearance parameterisation](appearance-parameterisation.md) for
the elicitation constraint that keeps it conjugate (asking for the non-russeted fraction avoids a
bilinear `blush × (1 − russet)`) and [the network design](model-v1-bayesian-network.md) for the
full appearance vector and why logit-normal beats Beta here.

One fragment of option A survives in a smaller role: **counts as a precision knob.** A notional *N*
patches, of which *n* are red, expresses "this observer resolves coverage coarsely" as weak evidence
about a real proportion — beta-binomial at the observation layer rather than Dirichlet-multinomial
at the parameter layer. Available, not needed, and it would break the conjugate chain upwards.

## The eight structural changes, and where each one went

These were listed as independent of the A/B/C choice, and they were: every one is now either
absorbed into the v1 design or explicitly overturned.

| # | Change | Now |
|---|---|---|
| 1 | `identify` returns a distribution, not a sample | folded into this file, below |
| 2 | `frequency` becomes Dirichlet weights over cultivars | `phi_g ~ Dirichlet(alpha)` in [the network](model-v1-bayesian-network.md) |
| 3 | An "unknown cultivar" option | [There must be an "other" outcome](identify-needs-other-outcome.md); its predictive is the prior predictive from `mu_0` |
| 4 | A hierarchical prior across cultivars | the whole Gaussian hierarchy, plus a pedigree GMRF |
| 5 | Observer reliability is three things | precision → `S_within`; bias → `b_o`; label reliability → the structured confusion model |
| 6 | ~~Ripeness is a latent, not a covariate~~ | **overturned** — see below |
| 7 | Frequencies are context-dependent | `phi_g` is per region by construction |
| 8 | ~~A colour judgement is coarse~~ | **overturned** — see below |

**Change 6 is overturned, and its conclusion survives its premise.** It argued that ripeness is a
per-apple latent nuisance variable, marginalized analytically under B and not under A — "the sharpest
single argument for B". The premise is wrong: once harvest and examination dates are recorded, the
durations *are* the covariates and there is no reason to introduce a latent ripeness at all
([Correction 1](model-v1-bayesian-network.md)). What survives is the argument's shape — B absorbs
covariates affinely and A does not — which is still the reason B won, just with an observed
coefficient instead of a latent one.

**Change 8 is overturned outright.** It read "60 % red" as a censored interval observation needing a
CDF the package does not have. Observations are **not** vague: a fruit either gave a value or it did
not, and a field too uncertain to record is absent rather than softened into a range. Vagueness
belongs to *cultivar descriptions*, which describe a distribution rather than a fruit and enter
through their own conjugate elicitation — see
[descriptions are not observations](cultivar-descriptions-are-not-observations.md). This is why the
interval-censoring row was struck from the deleted requirements document rather than scheduled.

## What this says about delayed sampling

Worth keeping, because it is the sharpest statement of what the machinery is *for* here. Under a
correctly-labelled, fully conjugate model the cultivar posterior is a finite sum of closed-form
predictives: the model is analytic and delayed sampling would never sample anything. So delayed
sampling is not buying variance reduction. It is buying the thing `updateDirichletColours`
demonstrated the absence of — a hand-derived conjugate update has to be re-derived by hand every time
the model changes, and collapses entirely the moment one non-conjugate part is added, whereas delayed
sampling degrades to sampling exactly that part and keeps the rest exact.

The v1 model does add exactly one such part: the latent label `z_t`. That is what makes the model a
mixture, ends analyticity, and lets delayed sampling earn its keep rather than merely automate a
closed form.

## Done when

**Done.** The decision is B with the parameterisation above, and each of the eight structural
changes has a recorded destination in the table.

## From the v1 requirements document (R13)

| # | Requirement | Needed for | Status |
|---|---|---|---|
| R13 | A distribution-valued result, including an "other" outcome | reporting a ranked candidate list | [reformulation](apple-model-reformulation-options.md), change 1 |
