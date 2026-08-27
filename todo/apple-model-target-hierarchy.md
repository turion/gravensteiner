---
status: closed
pkg: [gravensteiner]
closed_by: "c774c60 todo: observation model v1 review, network design, and requirements"
---
# The target model is a deep, crossed hierarchy — and that reorders this backlog

> **Partly superseded.** The v1 schema in `Gravensteiner.Model` and
> [the network design](model-v1-bayesian-network.md) write this hierarchy out formally, which is
> what the "Done when" section below asked for. Two consequences below did not survive that:
> **(4)** the label latent is per *tree*, not per apple, so the 2^n argument and the "SMC is
> required" conclusion are both too strong; and **(5)** ripeness should not be a latent at all,
> which makes it unconditionally conjugate rather than conditionally so. Both are corrected in
> place. The crossed-design finding in (3) survives and is strengthened with a concrete dimension
> estimate.

## Why it matters

The intended model is not "a prior per cultivar". It is a hierarchy: individual apples come from a
particular **tree** in a particular **year**; trees are correlated within a **cultivar**; harvest
date and observation date together imply a **ripeness**; and individual **pomologists** carry
biases, with the possibility that a specific apple in a collection they labelled is simply wrong.
None of that is being built now, but it decides which backlog items matter, and two of rev 5's
conclusions do not survive contact with it.

## The shape

```
  μ₀                                          -- grand mean: what an apple looks like
  μ_c   ~ N(μ₀,        Σ_cult)                -- cultivar c
  μ_t   ~ N(μ_c,       Σ_tree)                -- tree t of cultivar c: rootstock, site, age
  w_y   ~ N(0,         Σ_year)                -- year y: weather, shared by ALL trees
  μ_ty  ~ N(μ_t + w_y, Σ_ty)                  -- this tree in this year
  y_i   ~ N(μ_ty + r_i · d_c + b_o, Σ_obs)    -- apple i, judged by observer o
```

with `r_i` a ripeness derived from harvest and observation dates, `d_c` a cultivar-specific ripening
direction in appearance space, `b_o` observer *o*'s bias, and a per-apple indicator `z_i` for
"is this apple really the cultivar it was labelled".

## Six consequences

**1. Every level is normal-normal, so nothing new is needed *per level*.** A Gaussian hierarchy of
arbitrary depth is exactly the conjugacy the package already implements. Depth is free; it is the
*width* — the number of parents per node — that costs.

**2. Multiple parents appear at every level, not just one.**
[No supernodes](no-supernodes-for-multiple-parents.md) currently says "blocks the apple model";
with this hierarchy it blocks every level of it. `μ_ty` has two parents (`μ_t`, `w_y`); `y_i` has
three or four (`μ_ty`, `r_i`, `b_o`, and `z_i`'s choice of cultivar). It is not one obstacle in one
place, it is the shape of the whole model.

**3. The design is *crossed*, not nested, and that is qualitatively worse.** A year effect is shared
by every tree; an observer is shared across cultivars. So there is **no local merge that makes this
a forest**: grouping `μ_t` with `w_y` does not help, because the same `w_y` is also a parent of every
other tree's node that year. The junction-tree clique of a crossed design is essentially the entire
latent vector. Concretely, delayed sampling with supernodes **degenerates here to "maintain one
joint Gaussian over all entity latents"** — which is exact, and is essentially sparse Gaussian
belief propagation, but it means the supernode implementation *is* the implementation: a genuine
multivariate normal whose dimension grows with the data, with a dense O(*d*³) solve unless sparsity
is exploited. Order of magnitude for that *d*: cultivars O(10³), trees O(10²–10⁴), years O(10),
observers O(10²), times the appearance dimension. Dense is not viable at the top of those ranges.
This is squarely the non-tree tractable structure named in
[the paper's own future work](paper-future-work.md), so that item is not research-grade
decoration — it is where the target model lives.

**4. The label-error model is what breaks analyticity — but the grain is the tree, not the apple.**
Rev 5 recorded that under a fully conjugate reformulation the model would be exact and therefore
that [SMC integration](no-smc-integration.md) was not on the apple model's critical path. That is
wrong — a latent label makes the likelihood a **mixture** over the true cultivar, which is not
conjugate for the Gaussian means — but the correction as first written overshot. It assumed one
indicator `z_i` per apple and concluded a 2^n joint that forces sampling.

The v1 schema settles the grain: `Judgement` names a **tree**, so the latent is one categorical
`z_t` per tree. That is a much better position. The count drops from O(10⁵) apples to O(10³) trees;
each `z_t` is informed by every apple from that tree *and* every judgement of it, so its posterior
is sharp rather than near-flat; and the labels are conditionally independent given the shared
Gaussian latents, so a collapsed sweep visiting one tree at a time is natural and per-tree K-way
enumeration is feasible at a few hundred cultivars. The model is still a mixture (K^|T|) and still
not conjugate, so iteration over the discrete part remains unavoidable — but **Rao-Blackwellized
SMC is one way to run that, not the only one**, and a collapsed Gibbs sweep is the more obvious
fit. Label error remains the one feature that makes delayed sampling *earn* its keep rather than
merely automate a closed form. Details in [the network design](model-v1-bayesian-network.md).

**5. Ripeness should not be a latent variable at all.** The shape above writes `r_i · d_c` with a
latent ripeness `r_i` and a latent direction `d_c`, which is *bilinear* and therefore not
conjugate; the original conclusion was that ripeness "stays conjugate if and only if the dates are
recorded". The sharper statement is that once the dates are recorded there is no reason to
introduce `r_i`: **the durations are the covariates**, the only latent is the per-cultivar ripening
direction, and the term becomes an ordinary Bayesian linear regression — affine in one latent with
an observed coefficient, which is the case `conditionDist` already handles in its
`Normal (Product c (Var v)) (Const variance)` clause. A latent ripeness would buy nothing the
durations do not already carry.

The two clocks stay separate and are not interchangeable: on-tree maturation (bloom → harvest,
weather-driven and therefore coupled to `w_y`) and post-harvest storage (harvest → observation),
which for a stored apple can dominate. Recording harvest and examination dates therefore remains a
requirement rather than a nicety — and since bloom date is usually unrecorded, maturation has to be
approximated from harvest day-of-year, which only means anything given the tree's location.

**6. Identifiability is a data-collection constraint, not a code problem.** Each level is only
estimable given the right overlap: a tree effect needs several apples from that tree, a year effect
needs several years, and an observer's bias is separable from a cultivar's mean **only if observers
cross cultivars** — a pomologist who only ever judges Gravensteiner has a bias perfectly confounded
with Gravensteiner's mean. "Biases should become visible" therefore requires deliberate crossing in
who judges what. With one apple per tree the tree level is unidentifiable and merely inflates
variance, so the code should support *adding levels as the data allows* and degrade cleanly to
fewer, rather than assuming the full hierarchy.

## Two modelling opportunities this opens

**Clonality bounds the tree level.** All trees of a cultivar are grafted clones, so tree-to-tree
variation is environmental (rootstock, site, age, management), not genetic. That justifies a single
`Σ_tree` shared across all cultivars instead of one per cultivar — a large reduction in parameters
for free. The caveat is sports: red mutations of a cultivar are propagated as clones of their own,
so "clone" is only true within a sport.

**Cultivar means are not i.i.d.** Pedigrees are largely known, and appearance is heritable, so
`μ_c ~ N(μ₀, Σ_cult)` independently across cultivars wastes real information — the descendants of
Cox's Orange Pippin resemble it. Replacing it with a kinship-structured prior (a Gaussian Markov
random field over the pedigree) is a substantial win for exactly the rare cultivars where data is
thinnest, and it is once again crossed rather than tree-shaped.

## Consequences for other items in this backlog

- [No supernodes](no-supernodes-for-multiple-parents.md) — escalates from "blocks the apple model"
  to "is the implementation"; needs a growing-dimension multivariate normal with sparsity, not a
  pair.
- [No SMC integration](no-smc-integration.md) — a latent label ends conjugacy, so *some* iteration
  over the discrete part is required; per the correction to (4), SMC is one way to run it and a
  collapsed Gibbs sweep over trees is the more natural fit.
- [The paper's future work](paper-future-work.md) — the non-tree case is the target, not an
  afterthought.
- [Training must not grow the graph](streaming-training-with-bounded-memory.md) — rev 5's invariant
  ("the graph returns to its previous size") is wrong here. Apples are transient, but cultivar, tree,
  year and observer latents are permanent. The right invariant is that the graph grows with the
  number of *entities*, never with the number of *observations*.
- [Vector-valued variables](vector-valued-variables-and-dirichlet.md) — the multivariate normal is
  the needed half; combined with [russet is not a colour](russet-is-not-a-colour.md), the Dirichlet
  half has no remaining client.
- Records of variables (R8, done — see `Control.Monad.Bayes.DelayedSampling.Record`) — rises in
  value, since every entity at every level carries the same appearance record.
- [Marginals cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md) — under a
  crossed design the "trained model" is a joint Gaussian over all entities, not a per-cultivar
  summary, so persistence is a **sparse precision** matrix rather than a `Map Name` (R9).

## Done when

**Done.** The generative model is written out formally in
[the network design](model-v1-bayesian-network.md) — every level, every index set, and which
effects are crossed with which — against the v1 schema rather than a sketch. The answer to the
question this file left open is that supernodes **do** need to be sparse: the entity latent vector
is O(10⁴), so a dense factorisation is not viable. The requirements that follow from it are
tracked in [the requirements](model-v1-delayed-sampling-requirements.md).
