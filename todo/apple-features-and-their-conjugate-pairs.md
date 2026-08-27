---
status: closed
pkg: [gravensteiner, delayed-sampling]
closed_by: "f02577d todo: straighten the backlog into one coherent, sorted plan"
---
# The planned features, and which of them delayed sampling can absorb

> **Still the feature-to-mechanism index; three claims corrected.** The table below is the one place
> where every planned feature is mapped to a representation and a conjugate pair, so it stays. What
> changed since it was written: ripeness is an **observed covariate**, not a latent (so the bilinear
> row is gone); the label latent is **per tree**, not per apple (so the enumeration argument reverses);
> and the `Needs` column now links each row straight to the backlog item that owns it, since the
> numbered requirements document it used to cite has been dissolved into those items.

## Why it matters

`Main.hs` ended with a list of intended features — all apple properties, reliability of pomologists
and books, ripeness and season and location, weather influences. Each is a modelling decision with a
direct consequence for what `delayed-sampling` must support, and it is much cheaper to decide them
together, because the answer once tabulated is that **almost the whole list reduces to two
mechanisms**: a linear-Gaussian model on a transformed scale, and a Dirichlet/Beta prior over a
discrete outcome. Choosing representations that stay inside those two keeps the model analytic.

## The table

| Feature | Representation | Conjugate pair | Delayable | Needs |
|---|---|---|---|---|
| ground colour (green ↔ yellow) | normal on logit | normal-normal | **already** | nothing |
| overcolour (blush) extent | normal on logit of non-russeted fraction | normal-normal | **already** | nothing |
| overcolour pattern (blush/striped/flecked) | categorical | Dirichlet-categorical | yes | [discrete nodes](discrete-nodes-and-dirichlet-categorical.md) |
| russet extent | zero-inflated: Bernoulli × logit-normal | beta-Bernoulli + normal-normal | yes | [conjugate pairs](conjugate-pairs-beyond-normal.md); the indicator is *observed*, so no latent |
| joint covariance of the appearance vector | multivariate normal | normal-normal | yes | [vectors](vector-valued-variables-and-dirichlet.md) |
| weight | normal on ln weight | normal-normal | **already** | nothing |
| size (diameter, height) | normal on ln of each | normal-normal | **already** | nothing, if treated independently |
| weight ↔ size relation | ln *w* ≈ 3 ln *d* + ln ρ + noise | normal-normal, affine | yes | [affine form](value-affine-normal-form.md) |
| shape ratios (height/diameter, asymmetry) | normal on ln ratio | normal-normal | **already** | nothing |
| shape class (flat / round / conical) | categorical | Dirichlet-categorical | yes | [discrete nodes](discrete-nodes-and-dirichlet-categorical.md) |
| other markers (lenticels, bloom/waxiness) | Bernoulli per marker | beta-Bernoulli | yes | [discrete nodes](discrete-nodes-and-dirichlet-categorical.md), [conjugate pairs](conjugate-pairs-beyond-normal.md) |
| ripening on the tree | **observed** duration × latent per-cultivar direction | normal-normal regression | yes | [affine form](value-affine-normal-form.md); needs harvest date |
| storage after harvest | **observed** duration × latent per-cultivar direction | normal-normal regression | yes | [affine form](value-affine-normal-form.md); needs examination date |
| time of year | (sin, cos) as observed covariates | normal-normal regression | yes | [affine form](value-affine-normal-form.md) |
| tree | per-tree effect, one shared `S_tree` across cultivars | normal-normal | yes | [affine form](value-affine-normal-form.md), [supernodes](no-supernodes-for-multiple-parents.md); several fruit per tree to identify |
| year × region | effect shared across all trees in a region | normal-normal | yes | [affine form](value-affine-normal-form.md), [supernodes](no-supernodes-for-multiple-parents.md); **crossed**, so not a forest |
| location | region indexes both the year effect and `phi_g` | Dirichlet-categorical | yes | [discrete nodes](discrete-nodes-and-dirichlet-categorical.md) |
| weather | continuous covariates (degree-days, sunshine) | Bayesian linear regression | yes | [affine form](value-affine-normal-form.md) |
| observer precision | a noise variance | normal-inverse-gamma | partly | [conjugate pairs](conjugate-pairs-beyond-normal.md) (`Gamma`), and a variance slot that may be a variable |
| observer bias | additive per-observer term | normal-normal | yes | [affine form](value-affine-normal-form.md), [supernodes](no-supernodes-for-multiple-parents.md) |
| observer label reliability | structured confusion, two parameters per observer | beta-Bernoulli + categorical | yes | [stochastic parent](no-stochastic-parent-selection.md), [discrete nodes](discrete-nodes-and-dirichlet-categorical.md), [enumeration](exact-enumeration-of-discrete-latents.md) |

## What the table says

**Five features are implementable today.** Weight, size, shape ratios, ground colour and overcolour
extent are scalar normals on a log or logit scale with normal priors on their means —
`normalDS (Var mu) (Const variance)` with `conditionDist`'s existing `Normal (Var _) (Const _)`
clause. Adding them needs *nothing* from the backlog, which is what makes the scalar end-to-end
harness in [the network design](model-v1-bayesian-network.md) possible before the multi-parent
critical path — [stochastic parent](no-stochastic-parent-selection.md), [affine form](value-affine-normal-form.md), [vectors](vector-valued-variables-and-dirichlet.md) and [supernodes](no-supernodes-for-multiple-parents.md) — lands.

**Log and logit scales are doing the work.** Every constrained quantity here — positive weights,
coverages in [0, 1] — becomes unconstrained and roughly Gaussian under the same transform. That is a
design decision worth stating once rather than rediscovering per feature, and it is stated once, in
[the network design](model-v1-bayesian-network.md).

**Multi-parent support is the recurring blocker.** Most rows need it, always for the same reason: a
quantity depends on two or more parents. That is [affine form](value-affine-normal-form.md) → [vectors](vector-valued-variables-and-dirichlet.md) → [supernodes](no-supernodes-for-multiple-parents.md), and it is the difference
between a bag
of independent per-feature models and one joint model.

**Weather and year break the i.i.d. assumption, which changes the graph's shape.** Weather is a
property of a region-season, not of an apple, so every apple from that region-season shares one
parent. That turns independent leaves into a node with many marginalized children — precisely the
workload Invariant 2 governs, and which no current test exercises ([missing paper
examples](missing-paper-examples-as-tests.md)). It is
also the first place where "train, then discard the data" stops being obviously valid, since a later
apple from the same season is informative about an earlier one. And because these effects are
**crossed**, no local grouping restores a forest — see
[no supernodes](no-supernodes-for-multiple-parents.md).

**Every feature is optional in practice.** A book gives colour and season; a photo gives colour and
shape but no weight; a pomologist in an orchard gives everything. Partial observation is the normal
case, not an edge case, which is why the phase parameter and [mention vs not measured](mention-vs-not-measured-deferred.md)'s `Observed` matter — with a dozen
features there are far more observation patterns than can be written out by hand.

**Two rows still resist, and both are avoidable.** Observer *precision* as an unknown variance needs
normal-inverse-gamma, hence a `Gamma` constructor and a variance slot that may hold a variable, which
collides with the constancy requirement in
[marginal vs conditional](no-type-level-marginal-conditional.md); fixing precision per source class
("book", "photo", "in hand") avoids it. Ordinal features, if any are added, need probit thresholds on
a latent normal and hence a truncated-normal sampler — the Albert–Chib auxiliary variable is exactly
the kind of node delayed sampling would have to force. Neither is on the path for v1.

**The label row is the one that changes the algorithm rather than the model** — and it is much
cheaper than it used to look. Written as one latent indicator per *apple* it gives a joint over
indicators that cannot be enumerated, which is what once put SMC on the critical path. At the v1
grain the latent is one categorical per *tree*, informed by every fruit from that tree and every
judgement of it, so per-tree K-way enumeration inside a collapsed sweep is feasible and SMC is one
option rather than a requirement. See [the network design](model-v1-bayesian-network.md).

## Done when

Each row has a decision recorded — representation, whether it is learned or fixed, and whether it is
modelled at all in the first version — and the features that need nothing new are in the ported
model, with the rest gated on the numbered requirements above.
