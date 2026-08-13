# The planned apple features, and which of them delayed sampling can absorb

## Why it matters

`Main.hs` ends with a list of intended features:

```
{- Next steps:
* All relevant apple properties like weight, size, patterns, all shapes...
* Model for reliability of pomologists, photos & books
* ripeness, time of year of observation, location
* Weather influences
-}
```

Each of those is a modelling decision with a direct consequence for what `delayed-sampling` must
support, and it is much cheaper to make those decisions together than one at a time — because the
answer, once tabulated, is that **almost the whole list reduces to two mechanisms**: a
linear-Gaussian model on a transformed scale, and a Dirichlet/Beta prior over a discrete outcome.
Choosing feature representations that stay inside those two keeps the entire model analytic.

## The table

| Feature | Representation | Conjugate pair | Delayable | Needs |
|---|---|---|---|---|
| ground colour (green ↔ yellow) | normal on logit | normal-normal | **already** | nothing |
| overcolour (blush) extent | normal on logit, or binomial counts | normal-normal / beta-binomial | **already** | nothing; a presence layer for 0 and 1 |
| overcolour pattern (blush/striped/flecked) | categorical | Dirichlet-categorical | yes | [discrete nodes](discrete-nodes-and-dirichlet-categorical.md) |
| russet extent | zero-inflated: Bernoulli × logit-normal | beta-Bernoulli + normal-normal | partly | discrete nodes; a real `pdf` for `Beta` |
| joint covariance of the three | multivariate normal | normal-normal | yes | [supernodes](no-supernodes-for-multiple-parents.md) |
| weight | normal on ln weight | normal-normal | **already** | nothing |
| size (diameter, height) | normal on ln of each | normal-normal | **already** | nothing, if treated independently |
| weight ↔ size relation | ln *w* ≈ 3 ln *d* + ln ρ + noise | normal-normal, affine | yes | [supernodes](no-supernodes-for-multiple-parents.md) |
| shape ratios (height/diameter, asymmetry) | normal on ln ratio | normal-normal | **already** | nothing |
| shape class (flat / round / conical) | categorical | Dirichlet-categorical | yes | discrete nodes |
| other markers (lenticels, bloom/waxiness) | Bernoulli per marker | beta-Bernoulli | yes | discrete nodes; a real `pdf` for `Beta` |
| ripeness | latent, `rate × duration`, drives appearance affinely | normal-normal | yes if the dates are recorded | supernodes |
| ripeness, if ordinal | probit thresholds on a latent normal | normal-normal + truncation | partly | a truncated-normal sampler |
| harvest date | observed covariate; with bloom date gives on-tree maturation | normal-normal regression | yes | supernodes |
| storage duration (harvest → observation) | observed covariate | normal-normal regression | yes | supernodes |
| time of year | (sin, cos) as *observed covariates* | normal-normal regression | yes | supernodes |
| tree | per-tree effect, one shared `Σ_tree` across cultivars | normal-normal | yes | supernodes; several apples per tree to identify |
| year | per-year effect, shared across all trees | normal-normal | yes | supernodes; **crossed**, so not a forest |
| location | region as categorical, affecting `frequency` | Dirichlet-categorical | yes | discrete nodes |
| weather | continuous covariates (degree-days, sunshine) | Bayesian linear regression | yes | supernodes |
| observer precision | *N*, or a noise variance | — / normal-inverse-gamma | partly | a `Gamma` constructor for the variance case |
| observer bias | additive per-observer term | normal-normal | yes | supernodes |
| observer label reliability | confusion matrix, Dirichlet rows | Dirichlet-categorical | yes | discrete nodes + a latent per training label |

## What the table says

**Five features are implementable today.** Weight, size, shape ratios, ground colour and overcolour
extent are scalar normals on a log or logit scale with normal priors on their means —
`normalDS (Var mu) (Const variance)` with `conditionDist`'s existing `Normal (Var _) (Const _)`
clause. Adding them needs *nothing* from the backlog. Since two of them are appearance features,
[dropping the simplex](russet-is-not-a-colour.md) means a first port need not wait for the colour
machinery at all — which is a reversal of what rev 5 concluded when colours looked like the
hardest part of the list.

**Log and logit scales are doing the work.** Weight, size, shape ratios and colour proportions are
all constrained (positive, or on a simplex), and in each case the transform that makes them
unconstrained also makes them Gaussian-ish and therefore conjugate. The same trick handles pattern
extent (logit of a proportion) if one is willing to give up beta-binomial. Being deliberate about
this — "features live on a transformed scale where they are normal" — is a design decision worth
recording once rather than rediscovering per feature.

**Supernodes are the recurring blocker.** Most rows need them, always for the same reason: a
quantity depends on *two or more* parents (a cultivar mean and a ripeness, a cultivar mean and an
observer bias, an alr coordinate and several weather covariates). That is
[no supernodes](no-supernodes-for-multiple-parents.md), and it is what makes the difference between
a bag of independent per-feature models and one joint model.

**Weather breaks the i.i.d. assumption, which changes the graph's shape.** Weather is a property of
an orchard-season, not of an apple, so every apple from that orchard-season shares one parent. That
turns a set of independent leaves into a node with many marginalized children, which is precisely
the workload Invariant 2 and `prune` govern
([`graft` and `prune` scan for all marginalized children](graft-does-not-use-invariant-2.md)) and
which no current test exercises
([missing paper examples](missing-paper-examples-as-tests.md)). It is also the first place where
"train, then discard the data" stops being obviously valid, since a later apple from the same
season is informative about an earlier one. The same applies to the tree and year rows, and
[the target hierarchy](apple-model-target-hierarchy.md) shows why it is worse than it looks: those
effects are *crossed*, so no local grouping restores a forest.

**Every feature is optional in practice.** A book gives colour and season; a photo gives colour and
shape but no weight; a pomologist in an orchard gives everything. So partial observation is not an
edge case but the normal case, which raises the priority of
[records of variables and partial observation](records-of-variables-and-partial-observation.md) —
with a dozen features, the number of observation patterns is far past what can be written out by
hand.

**Only two rows resist.** Ordinal ripeness needs a truncated normal, which is a sampler the package
does not have and which is not a conjugate update at all (it is the Albert–Chib auxiliary-variable
trick, and the auxiliary variable is precisely the kind of node delayed sampling would have to
force). Observer *precision* as an unknown variance needs normal-inverse-gamma, hence a `Gamma`
constructor and a variance slot that may hold a variable — which collides with the constancy
requirement discussed in
[marginal vs conditional](no-type-level-marginal-conditional.md). Both are avoidable: fix the
observer precision per source class ("book", "photo", "expert") rather than learning it, and treat
ripeness as continuous.

**A third row resists for a different reason.** Observer *label* reliability is conjugate line by
line, but it introduces one latent indicator per apple, so the joint over indicators cannot be
enumerated and the appearance likelihood becomes a mixture. It is the only entry in the table that
changes the *algorithm* rather than the model, and it is what puts
[SMC integration](no-smc-integration.md) on the critical path.

## Done when

Each row has a decision recorded — representation, whether it is learned or fixed, and whether it
is modelled at all in the first version — and the features that need nothing new (weight, size,
shape ratios) are in the ported model, with the rest gated on the backlog items named above.
