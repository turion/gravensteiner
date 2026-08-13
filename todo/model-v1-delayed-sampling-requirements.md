# What `delayed-sampling` must gain to run observation model v1

## Why it matters

[The network design](model-v1-bayesian-network.md) is a specification; this is the list of
capabilities it requires, so that the backlog can be worked in an order that converges on it.
Most rows already have a backlog item and are cross-referenced rather than restated. Six are new,
and one of those is deeper than anything currently recorded.

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
| R12 | An observation model on missingness itself | literature that does not mention a feature | **new** |
| R13 | A distribution-valued result, including an "other" outcome | reporting a calibrated probability | [reformulation](apple-model-reformulation-options.md), change 1 |

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
   nothing moves back. Either the sweep re-derives the Gaussian block from scratch per tree
   (correct, expensive) or there is a genuine downdate. This is the requirement most likely to be
   discovered late, so it is recorded now.

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

A caveat worth recording: information form makes conditioning cheap and marginalization
expensive, which is the opposite trade-off from the covariance form the package currently uses in
`conditionDist`. Since this model conditions constantly (every fruit) and marginalizes rarely (to
report), information form is the right default, but it is a genuine representational change and
not a drop-in.

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

## R12 — missingness is not always ignorable

The phase parameter says "this field is absent" and says nothing about *why*. Three reasons are
mixed together and they are not statistically equivalent:

- **Not measured.** A photo cannot show weight. Missing at random given the source class;
  ignorable, which is what delayed sampling does naturally with a never-grafted variable.
- **Not mentioned.** A monograph that omits russet is weak evidence of little russet, because
  authors mention what is notable. Informative, and ignoring it throws away real signal while
  treating it as zero introduces a false one.
- **Absent.** A pomologist recording no russet is an observation of zero, which under the chosen
  parameterisation is the observed presence indicator.

Only the third is currently expressible. The first is free. The second needs the source class
(R-review, Tier 1) plus a Bernoulli likelihood on the mention indicator conditioned on the latent
value — a small model, but it must be *decided* rather than defaulted, because ingesting the
literature is the immediate next step and the choice is baked into the ingestion.

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
R9, R10 and R12 are decisions to record before they become expensive: R12 before literature
ingestion, R9 and R10 before there is a fitted state worth keeping.

## Done when

Each row has an owner item in this backlog, R1's two sub-requirements have a prototype answer
(even a slow one), and the scalar end-to-end harness described above exists so that every later
requirement is validated against a working pipeline rather than in isolation.
