# What `delayed-sampling` must gain to run observation model v1

## Why it matters

[The network design](model-v1-bayesian-network.md) is a specification; this is the list of
capabilities it requires, so that the backlog can be worked in an order that converges on it.
Most rows already have a backlog item and are cross-referenced rather than restated. Five are new,
one of those is deeper than anything currently recorded, and one earlier row is struck.

The headline: **the model is not blocked on distributions, it is blocked on graph structure.**
Almost every conjugate pair it needs is normal-normal, which the package already implements. What
it needs is the ability to represent a node whose parents are numerous, whose parent *identity* is
itself random, and whose joint is sparse rather than tree-shaped.

## The requirements

| # | Requirement | Needed for | Status |
|---|---|---|---|
| R1 | A node whose parent is selected by a discrete latent | `mu_{z_t}` — the cultivar label | **new, deepest** |
| R2 | Linear combination of many latent vectors with observed scalar coefficients | the fruit mean `m_i` | extends [affine normal form](value-affine-normal-form.md) |
| R3 | Multivariate normal node, vector carrier, affine maps | the appearance vector at every level | [vectors](vector-valued-variables-and-dirichlet.md), [supernodes](no-supernodes-for-multiple-parents.md) |
| R4 | Sparse precision representation / Gaussian belief propagation | the crossed Gaussian block, *d* ≈ O(10⁴) | **new as a requirement**; an aside in [supernodes](no-supernodes-for-multiple-parents.md) |
| R5 | Discrete nodes and Dirichlet-categorical | `z_t`, `phi_g`, `overcolourPattern` | [discrete nodes](discrete-nodes-and-dirichlet-categorical.md) |
| R6 | Exact enumeration of a discrete latent with the Gaussian part marginalized | the per-tree K-way posterior | [enumeration](exact-enumeration-of-discrete-latents.md) |
| R7 | `Beta` with a real `pdf`, and `Gamma` | russet presence, observer accuracy, unknown variances | [conjugate pairs](conjugate-pairs-beyond-normal.md) |
| R8 | Records of variables, per-field partial observation | `Fruit p`, `Colours p` | [records](records-of-variables-and-partial-observation.md) |
| R9 | Persistence of a sparse joint over entity latents | train once, identify later | reshapes [marginals](marginals-cannot-be-saved-or-reloaded.md) |
| R10 | Incremental extension of a fitted graph | hundreds of collections per year | **new** |
| R11 | Bounded memory: fruit transient, entities permanent | 10⁵ fruit, 10³ entities | [streaming](streaming-training-with-bounded-memory.md) |
| R12 | Observation status in the type: exact / not mentioned / not measured | knowing *why* a field is absent | **new** |
| R13 | A distribution-valued result, including an "other" outcome | reporting a ranked candidate list | [reformulation](apple-model-reformulation-options.md), change 1 |
| R14 | ~~Interval-censored observations~~ | **struck** — descriptions are not observations; see [descriptions](cultivar-descriptions-are-not-observations.md) | dropped |
| R15 | A moment-form serving cache extracted from the information-form fit | answering queries without refitting | **new** |

## R1 — stochastic edges, and why this is the hard one

Every other requirement is about the *contents* of a node or the *number* of its parents. R1 is
about **which node is the parent**, and that is a different kind of thing.

The fruit node's mean contains `mu_{z_t}`: the cultivar mean of whichever cultivar tree *t*
actually is. `z_t` is latent, so the *edge* from a cultivar node to a fruit node is itself random.
Nothing in `delayed-sampling` has a notion of this — `Value` can hold a `Var`, and `getParents`
reads the variables an expression mentions, but there is no way to write "the parent is one of
these K variables, with these probabilities". The graph is a fixed structure whose nodes carry
distributions; here the structure is part of what is being inferred.

This is the paper's spike-and-slab / stochastic-branching case (§ on programs whose control flow
depends on a random choice) generalised from two branches to K, and the paper's own treatment is to
*force* the branching variable — sample it, then proceed with a known structure. That is exactly
the right answer here, and it is the shape of the algorithm the network design calls for: force
`z_t`, and everything downstream is conjugate. So R1 does not require inventing a new
delayed-sampling operation; it requires that forcing a discrete variable and *then* building the
graph is expressible and cheap, and that the K alternatives can be evaluated without rebuilding
the whole graph K times.

Two sub-requirements fall out, and they are the practical content of R1:

1. **Evaluating K alternatives against a shared marginalized context.** Computing the posterior
   over `z_t` means evaluating the fruit likelihood under each candidate cultivar mean, against a
   Gaussian block that is identical in all K cases. Naively that is K grafts and K rebuilds; what
   is needed is to graft the shared context once and score K alternatives against it. Without this
   the per-tree posterior costs K times too much, and K is a few hundred.
2. **Retraction.** A collapsed Gibbs sweep revisits `z_t` after having conditioned on it, so the
   effect of the previous value must be removable. Delayed sampling is built around monotone
   accumulation of evidence: `realize` and `observe` move nodes forward through I → M → R and
   nothing moves back, and `observe` has additionally already applied its `score` to the weight.
   Either the sweep re-derives the Gaussian block from scratch per tree (correct, expensive) or
   there is a genuine downdate. This is the requirement most likely to be discovered late, so it is
   recorded now.

   **R1 and R4 converge here, which is a useful coincidence.** In information form the evidence
   from one observation is an *additive* contribution to the precision and the information vector,
   `Λ += Aᵀ S⁻¹ A` and `η += Aᵀ S⁻¹ y`, so retracting it is subtraction of the same two terms —
   exact, local, and O(block size). In moment form there is no comparable downdate. So the
   representational change R4 needs for scale is the same one R1 needs for correctness, and neither
   should be designed without the other.

Note that R1 interacts with the confusion model: `sim(c, c')` is derived from the Gaussian
posterior, so the discrete block's weights depend on the continuous block's current state. The two
cannot be fitted in one pass, and the fixed-point iteration between them is part of the algorithm
rather than an implementation detail.

## R2 and R4 — the shape of the Gaussian block

R2 is the mechanical part. The fruit mean is a sum of six latent vectors plus two
observed-coefficient regression terms, so `Value` must express `sum_j (c_j *^ Var v_j) + const`
with `c_j` known scalars and `v_j` vector-valued. [The affine normal form](value-affine-normal-form.md)
proposes exactly this normal form for the scalar case; the generalisation is that the coefficients
become scalars against vector variables, and later matrices. Nothing about it is conceptually hard
and it should be done first, because R3 and R4 both consume it.

R4 is the part that decides whether the model runs at all. Because the design is crossed at three
levels independently, no local merge yields a forest and the supernode degenerates to a single
joint over essentially all entity latents:

```
  trees        10^3  x d=6   =  6 000
  cultivars    10^2  x d     =    600
  year x region 10^2 x d     =    600
  observers    10^2  x d     =    600     (bias)  + 2 per observer (calibration)
  sources        ~5  x d     =     30
  global        few  x d
                             --------
                              ~ 10^4
```

Dense Cholesky at *d* = 10⁴ is ~10¹² flops per solve and O(10⁸) doubles of covariance — not
viable, and it gets worse as trees accumulate. But the precision matrix is extremely sparse: a
fruit couples one tree, one year×region, one observer, one source and one collection, so each
fruit contributes a constant-size block. So the requirement is a **sparse precision (information
form) representation with a fill-reducing ordering**, i.e. Gaussian belief propagation, and it is
not an optimisation to add later — the model sits at the extreme where dense supernodes fail,
rather than near it.

### Two representations, because training and serving want opposite things

Information form makes conditioning cheap and marginalization expensive; moment (covariance) form
is the reverse. The package's `conditionDist` is moment form today. The two phases of this system
sit on opposite sides of that trade-off, so the resolution is not to pick one:

- **Training / ingestion** conditions constantly (once per fruit, O(10⁵) times), retracts during
  Gibbs sweeps (R1), and grows the latent vector as trees and observers appear (R10). All three are
  additive-and-local in information form and all three are expensive in moment form.
- **Serving** — enter a collection, get a ranked list of likely cultivars — is a *marginalization*.
  For each candidate *c* it needs the predictive `p(x_new | z_t = c, all data)`, which means the
  marginal posterior of `mu_c` plus the relevant shared effects, with a fresh `a_t` from the prior
  for the unseen tree.

The reconciliation is that serving marginalizes over a **small, fixed** subset and does so against
a *static* fitted state, so it is computed once per refit rather than once per query:

```
  per candidate cultivar:  marginal mean and covariance of mu_c     d x d = 36 numbers
  x K ~ 300 cultivars                                               ~ 11 k numbers
  plus the shared blocks actually referenced by a query
    (w_{y,g}, b_o, e_s, and the priors S_tree, S_within)            small
                                                                    ------
                                                                    << 1 MB
```

Note what is *not* needed: the cross-covariance between `mu_c` and `mu_c'`. Ranking evaluates each
candidate's predictive independently and never conditions on one cultivar while predicting another,
so the serving artifact is K separate *d*×*d* blocks, not one 1800×1800 joint. Within a candidate,
several fruit from the same collection do share `a_t`, so the collection's joint predictive
integrates one *d*-dimensional latent — a small local computation, and the reason a collection is a
better query unit than a single fruit.

So: **fit in information form, extract a moment-form serving cache once per refit, answer queries
from the cache.** That also settles what R9 persists — the serving cache is the artifact worth
shipping, the information-form state is the thing worth checkpointing, and they are not the same
object. And the "other" outcome comes free, since its predictive is the prior predictive from
`mu_0` with the full between-cultivar covariance added.

## R9 and R10 — the trained model is no longer a `Map`

[Marginals cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md) is written
around extracting a per-entity marginal and reloading it with `initialize`. Under a crossed design
that is **lossy in a way that matters**: the posterior over cultivar means is correlated — because
they share `mu_0`, a pedigree GMRF, and every observer and year effect — and storing per-cultivar
marginals discards precisely the correlations that let one cultivar's data inform another's. So
persistence is a sparse precision matrix over the entity latents plus the Dirichlet, calibration
and Beta parameters, and the round-trip test in that file becomes: reload, observe more, and check
the result equals a single-session fit. That equality is a sharp test of the whole conjugate
apparatus and nothing currently tests it.

R10 is the practical form of the same point. Hundreds of collections a year means the system must
extend a fitted state rather than refit, and — because trees and observers are new entities —
extension has to grow the latent vector, not just condition on it. In information form that is
cheap (a new entity is a new diagonal block plus a few off-diagonal entries), which is a second
argument for R4.

## R12 — observation status belongs in the type

> **Implemented as a two-way `Observed a | NotObserved` for now** in
> `Control.Monad.Bayes.DelayedSampling.Record` — the three-way split below is deferred until a source
> class exists to condition `NotMentioned`'s mention likelihood on; see
> [mention-vs-not-measured-deferred](mention-vs-not-measured-deferred.md).

`Maybe` collapses several statistically distinct situations into one `Nothing`. They need to be
distinguished at the point where the distinction is *known* — data entry — because it cannot be
recovered later. The phase parameter is the right place, since it is already generic:

```haskell
-- | Why a fruit observation has no value, recorded where it is known.
--   Observations are never vague: a fruit either gave a value or it did not.
data Observed a
  = Observed a
    -- ^ Measured. Absence of a feature is @Observed 0@, not a missing value:
    --   "no red on this apple" is an observation, and an informative one.
  | NotMentioned
    -- ^ The observer could have recorded it and did not. Weak evidence, because
    --   people record what is notable.
  | NotMeasured
    -- ^ The source could not produce it at all: a photograph has no weight, and a
    --   photograph of one side cannot give russet extent. Ignorable given the source.
  deriving (Show, Eq, Functor, Foldable, Traversable)
```

There is deliberately **no vague case**. Vagueness belongs to *cultivar descriptions*, which are
statements about a distribution rather than about a fruit, and they get their own type — see
[descriptions are not observations](cultivar-descriptions-are-not-observations.md). Uncertain fields
of a real observation (half the surface is hidden, shape depends on perspective) are `NotMeasured`
or discarded, not softened into a range.

Used as the phase, `Fruit Observed` is a real-world record and `Fruit Identity` a simulated one, so
the existing `barbies` dependency and `UUIDMap`'s indexed instances keep working unchanged.
Deliberately **no `Applicative`/`Monad`**: `<*>` would have to pick a winner between `NotMeasured`
and `NotMentioned`, and there is no defensible choice, so the ambiguity should be resolved
per-field at the call site rather than hidden in an instance.

What each case costs in the likelihood:

| Case | Contribution | Conjugate |
|---|---|---|
| `Observed x` | the density at *x* | yes |
| `Observed 0` on a zero-inflated feature | the presence indicator, a Bernoulli | yes (beta-Bernoulli) |
| `NotMeasured` | none — an ungrafted variable, which is exactly what delayed sampling does | yes, free |
| `NotMentioned` | a Bernoulli on the mention indicator, conditioned on the latent value | yes, but needs the source class |

`NotMeasured` being free is worth stating: the ignorable case is the one delayed sampling already
handles correctly by never grafting the variable, so the type is mostly making the *non*-ignorable
cases visible.

## R14 — struck

R14 said that the literature corpus is interval-censored and therefore non-conjugate. That was a
category error: "medium-large" in a monograph is not a vague *observation of a fruit*, it is a claim
about the cultivar's **distribution**, and no fruit was measured. Elicited into the conjugate family
— a location, an effective count, and optionally a spread — it enters through the same normal-normal
update as an observation and needs nothing new. So this row **removes** a requirement instead of
adding one. The full argument, the types, and the three hazards specific to literature (books copy
each other; books describe show fruit; a described spread constrains the total variance rather than
any one component) are in
[cultivar descriptions are not observations](cultivar-descriptions-are-not-observations.md).

## What is already supported today

Worth stating so the port is not delayed unnecessarily. Under the v1 parameterisation, a scalar
version of the model — one feature, one level of hierarchy, labels observed — is implementable
right now: `normalDS (Var mu) (Const variance)` with `conditionDist`'s existing
`Normal (Var _) (Const _)` and `Normal (Product c (Var _)) (Const _)` clauses covers a cultivar
mean, an observed-covariate ripening term, and an observation. That is enough to build the
end-to-end harness — ingest, fit, report, evaluate — on one feature and grow it, rather than
waiting for R1 through R4.

## Ordering

R2 → R3 → R4 is the critical path and each is a prerequisite for the next. R5 → R6 → R1 is the
discrete path, and R1's two sub-requirements (shared-context scoring, retraction) are the ones to
prototype early because they are the least certain. R7, R8, R11 and R13 are independent and small.
R9, R10 and R12 are decisions to record before they become expensive. **R12 and the description
elicitation belong before literature ingestion**, since the corpus cannot be re-read cheaply and the
adjective vocabulary is part of the data rather than of the reader. The elicited strength cap belongs
there too, but as a bound rather than a correction: capped small, it makes derivative sources harmless
without resolving who copied whom, and it guarantees measured data eventually dominates. R9, R10 and
R15 come before there is a fitted state worth keeping.

## Done when

Each row has an owner item in this backlog, R1's two sub-requirements have a prototype answer
(even a slow one), and the scalar end-to-end harness described above exists so that every later
requirement is validated against a working pipeline rather than in isolation.

"Validated" means measured, not merely running: the harness is only useful with the accuracy and
calibration figures from [no evaluation harness](no-evaluation-harness.md) attached, since every
requirement here is justified by an argument about accuracy that nothing has yet checked.
