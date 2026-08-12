# The apple model's likelihood is not settled — three reformulations

## Why it matters

`gravensteiner/app/Main.hs` performs its conjugate update *by hand*, in pure Haskell:
`updateDirichletColours` is the update, `updateModel`/`updateAppleSortPrior` fold it over the
training set, and no inference monad appears anywhere except `identify`. Porting to delayed
sampling is therefore not "wrap the existing code" — it is "restate the model as a graph and let
`observe` do what `updateDirichletColours` does now". That rewrite is the moment to change the
model, and several parts of it should change, because the current likelihood is chosen for
conjugacy-by-hand rather than for fitting apples.

Three things are unsettled, and they are independent: what a colour observation *is*, what carries
the per-cultivar parameters, and what `identify` returns.

## What the model does today

Per cultivar *c*, with `Colours` a point on the 3-simplex (four proportions summing to 1):

```
  v_c, η_c                     -- DirichletColoursPrior: {yellow,red,green,brown}Prior, pseudocount
  α_c ~ p(α | v_c, η_c)        -- sampleDirichletColours: 10 importance samples, Gamma(1,1) proposals
  x   ~ Dirichlet(α_c)         -- coloursLikelihood, evaluated at the observed proportions
```

The middle level is the [conjugate prior of the Dirichlet
distribution](https://en.wikipedia.org/wiki/Dirichlet_distribution#Conjugate_prior_of_the_Dirichlet_distribution),
*p*(α) ∝ *B*(α)^−η · exp(−Σₖ *v*ₖ αₖ). `dirichletColoursLikelihood` is that density,
`updateDirichletColours` is its update *v*ₖ ← *v*ₖ − ln *x*ₖ, η ← η + 1, and
`dirichletColoursNormalizable` is its normalizability condition Σₖ exp(−*v*ₖ/η) < 1. The
derivation is right; the problem is that this family has **no closed-form normalizer**, which is
the entire reason `sampleDirichletColours` and its 10-sample importance sampler exist. Delayed
sampling cannot rescue it — see the gamma caution in
[only `Normal` is usable](conjugate-pairs-beyond-normal.md).

`frequency` is a counter that `identify` never reads (its own FIXME says it should be Dirichlet
weights), and `identify` returns a *sampled* `Name` rather than a distribution.

## Option A — counts, and Dirichlet-multinomial

Treat the observation as **counts, not proportions**: *N* notional surface patches, of which
*n*_red are red. "60 % red" at *N* = 20 is *n*_red = 12. Then

```
  θ_c ~ Dirichlet(α₀)          -- α₀ fixed, or itself hierarchical
  n   ~ Multinomial(N, θ_c)
```

The exotic hyperprior **disappears**. There is nothing left to learn about a concentration vector,
because what is being learned is θ_c itself, and Dirichlet-multinomial is conjugate: the
predictive for a new apple is a ratio of Γ's, so `identify` needs no Monte Carlo at all. Zeros
stop being fatal — *n*_green = 0 is an ordinary outcome rather than a point outside the support
([exact zeros are fatal](apple-model-zero-colours-are-fatal.md)). Overdispersion across apples of
one cultivar comes for free, parameterised by Σα₀.

*N* looks like an embarrassment but is really the **reliability knob**: a careless pomologist, or
a bad photograph, is a small *N* — weak evidence about a real proportion. That is one concrete,
cheap answer to the observer-reliability question below.

Costs: *N* has to be chosen or modelled; and multinomial counts cannot absorb a continuous
covariate affinely (see the trade-off). Needs a `Dirichlet` node and
[vector-valued variables](vector-valued-variables-and-dirichlet.md), plus a discrete child
([no discrete nodes](discrete-nodes-and-dirichlet-categorical.md)).

## Option B — logistic-normal on the additive log-ratio

Map the composition into ℝ³ with the additive log-ratio transform,
*y* = (ln *x*_y/*x*_b, ln *x*_r/*x*_b, ln *x*_g/*x*_b), and put

```
  μ_c ~ N(μ₀, Σ₀)              -- hierarchical across cultivars
  y   ~ N(μ_c, Σ)
```

This is the formulation that fits *this package*: normal-normal is the only conjugacy implemented,
the mean is an affine expression, and Σ may be full — so "red trades off against green, because
that axis is ripeness, while russeting varies independently" is expressible. A Dirichlet cannot
say that; its correlation structure is fixed once Σα is fixed.

Decisively, **B is the only option in which covariates and per-apple latents enter affinely**:

```
  y = μ_c + ripeness · d_c + Σ_j β_j z_j + noise
```

is exactly the paper's affine-transformation machinery, so an *unobserved* ripeness is
marginalized analytically instead of sampled. Since nearly every planned feature is a continuous
covariate ([apple features and their conjugate pairs](apple-features-and-their-conjugate-pairs.md)),
this is the long-run shape of the model.

Costs: alr(0) = −∞, so a **structural-zero layer is mandatory** — a presence indicator per colour
(Bernoulli with a Beta prior, i.e. beta-Bernoulli conjugacy) and a logistic-normal over the
present parts only. Needs vector-valued normals, hence
[supernodes](no-supernodes-for-multiple-parents.md).

## Option C — keep the hyperprior and sample it properly

Status quo, repaired: make `quality` configurable rather than a hard-coded 10, remove the
`print`/`traceShowWith` calls, and check the importance weights (the `Exp (sum α)` factor is the
reciprocal Gamma(1,1) density, which is right, but the target is unnormalized so the estimate is
usable only after `proper`). Recommended only as a stopgap. It keeps a level of the hierarchy that
has no closed form, that the data does not need, and that forces Monte Carlo into `identify` —
the one place where an exact answer is otherwise available.

## The trade-off, stated once

**Dirichlet-multinomial is robust to zeros and needs no hyperprior, but its parameters cannot be
an affine function of anything. Logistic-normal absorbs covariates and latents affinely but is
undefined at zero.** That is the whole choice, and it does not have a dominant side.

Recommendation: **A now, B as the target.** A makes today's model correct and exact, and the
conjugacies it needs (Dirichlet-multinomial, a discrete node) are ones the package wants anyway. B
requires vector normals and supernodes, neither of which exists. The presence layer from B is
worth having under either option, because "this cultivar is never brown" is a real claim about
apples that neither likelihood expresses otherwise. A hybrid is legitimate and probably where this
ends up: Dirichlet-multinomial for colours, linear-Gaussian for everything continuous.

**A port is possible today, before any of this lands**, at reduced fidelity: option B with a
*diagonal* Σ makes the three alr coordinates three independent scalar chains,
`μᵢ ~ N(mᵢ, s²)` and `yᵢ ~ N(Var μᵢ, σ²)`, which `normalDS`/`observe` already support —
`conditionDist` handles `Normal (Var parentVar) (Const variance)` directly. Colours with a zero
must be dropped or regularised first. That is worth doing as an end-to-end smoke test of the
package against a real model even though the statistics are wrong.

## Structural changes, independent of A/B/C

1. **`identify` must return a distribution, not a sample.** Its type is
   `Apple -> Model -> m Name`, and it draws from `proper . fromWeightedList`, throwing away the
   very thing the caller wants ("how sure are you?"). It should return
   `Map Name (Log Double)`, normalized, or a `Categorical Name`.
2. **`frequency` becomes Dirichlet weights over cultivars**, as its FIXME says: prior
   pseudocounts α₀, observed counts *n*_c, predictive (α₀ + *n*_c)/Σ(α₀ + *n*). `identify`
   currently ignores it entirely, so a cultivar seen once competes on equal terms with one seen a
   thousand times. Note that `initialAppleSortPrior` sets `frequency = 0`, which as a Dirichlet
   weight means "impossible", not "unseen"; 1 (Laplace) or a fitted concentration is meant.
3. **An "unknown cultivar" option** — the `identify` FIXME about hallucination. Three mechanisms,
   in increasing ambition: (a) an explicit "other" component whose predictive *is* the
   hierarchical base measure's predictive, which is nearly free once (4) exists; (b) a
   Chinese-restaurant / Dirichlet-process prior on cultivar identity, so a genuinely new cultivar
   can be created — a good fit, since real cultivars number in the thousands and the training set
   will always be a small sample of them; (c) abstention: report the posterior and refuse to
   answer below a calibrated threshold, which is a decision rule rather than a model change and
   should be kept separate from (a)/(b).
4. **A hierarchical prior across cultivars** — `Main.hs`'s "Actually I want to have a prior over
   that as well?" With three training apples and three cultivars, each per-cultivar posterior is
   the prior plus a single point. Shrinkage towards a learned "generic apple" is not a refinement
   here, it is what makes the model usable at all, and it is what makes (3a) available.
5. **Observer reliability is three different things**, and "Model for reliability of pomologists,
   photos & books" conflates them: (i) *precision* — how finely this observer resolves colour,
   which is Option A's *N* or Option B's noise variance; (ii) *bias* — a systematic tilt, e.g. an
   observer who calls everything red, which is an additive per-observer term in B and hence
   affine and delayable; (iii) *label reliability* — the recorded cultivar *name* in training may
   simply be wrong, which is a confusion matrix with Dirichlet rows, or a per-observer Beta
   "is this label right". (iii) is the expensive one: it turns every training label into a latent
   and makes training itself a mixture.
6. **Ripeness is a latent, not a covariate.** It drives colour (green → yellow/red), and it is
   usually *unknown* at observation time, so it is a per-apple nuisance variable to be
   marginalized — which under B is analytic and under A is not. This is the sharpest single
   argument for B.
7. **Frequencies are context-dependent.** "Which cultivars are plausible" differs between a
   German supermarket and a heritage orchard; `frequency` should ultimately be conditioned on
   location and season rather than global.
8. **A colour judgement is coarse.** "60 % red" is really "somewhere around 55–65 %" — a
   *censored* or interval observation. `observe` cannot express that: it takes a point value and
   calls `pdf`, so an interval needs a CDF the package does not have. Recording it as a limitation
   rather than a plan; the honest cheap approximation is to inflate the observation noise, which
   Option B has a slot for and Option A folds into *N*.

## The consequence for delayed sampling

Under A or B with conjugate priors throughout, the cultivar posterior is a *finite sum of
closed-form predictives*: the model is fully analytic and delayed sampling would never sample
anything. That is the Rao-Blackwellization limit named in
[no SMC integration](no-smc-integration.md) — which makes the apple model a good *demonstration*
for that item rather than a client of it, and means SMC is not on the critical path for the port.

It also sharpens what delayed sampling is actually for here. It is not variance reduction, since
there would be no variance. It is that `updateDirichletColours` is a hand-derived conjugate update
which has to be re-derived by hand every time the model changes — and the moment one
non-conjugate part is added (a censored observation, label uncertainty, a non-Gaussian weather
effect) the hand-derived version collapses, whereas delayed sampling degrades to sampling exactly
that part and keeps the rest exact.

## Done when

This is a decision, not code: A, B or C recorded here with a reason, and a position on each of the
eight structural changes. Nothing should be ported until that is written down, because A and B do
not need the same features from `delayed-sampling` — A needs a `Dirichlet` node and a discrete
child, B needs vector normals and supernodes, and building both is roughly twice the work.
