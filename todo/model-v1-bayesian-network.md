# The Bayesian network for observation model v1

## Why it matters

[The target hierarchy](apple-model-target-hierarchy.md) closed by saying the next concrete step
was to write the generative model out formally — every level, every index set, and which effects
are crossed with which — because that document determines how much of the delayed-sampling
machinery has to exist. This is that document, written against the v1 schema in
`Gravensteiner.Model` rather than against a sketch, and it fixes two things the hierarchy note
got wrong.

Scope decisions taken: the candidate set is **regional, a few hundred cultivars**, so K-way
enumeration per tree is feasible and no shortlisting is needed. Appearance uses **ground colour
plus overcolour** rather than a simplex, per [the review](model-v1-review.md).

## Index sets

| Index | Meaning | Schema | Order |
|---|---|---|---|
| *c* | cultivar, plus one **other** outcome | `Cultivar` | 10² – 10³ |
| *t* | tree | `Tree` | 10³ and growing |
| *y* | year | from `Collection.date` | 10¹ |
| *g* | region | `Tree.location` (to be added) | 10¹ |
| *o* | observer or pomologist | `Person` | 10² |
| *s* | source class: in-hand / photo / monograph / website | to be added | ~5 |
| *k* | collection | `Collection` | 10³ – 10⁴ |
| *i* | fruit | `Fruit` | 10⁴ – 10⁵ |
| *j* | judgement | `Judgement` | 10³ |
| *l* | cultivar description | `Description` (to be added) | 10³ – 10⁴ |

Note the two very different growth rates. Fruit and collections grow without bound as data comes
in; cultivars, regions, source classes and years do not, and trees and observers grow slowly. That
split is what makes bounded-memory inference possible at all, and it is the invariant the graph
must respect.

Descriptions are the odd one out: they are indexed by cultivar rather than by tree, they carry no
year, collection or ripeness, and they are the only source of information about a cultivar nobody has
sampled — which for a regional set of a few hundred will be most of them at first. See
[descriptions are not observations](cultivar-descriptions-are-not-observations.md).

## The appearance vector

All features live on unconstrained scales, chosen so that each one is plausibly Gaussian and the
transform is the same one that removes the constraint:

```
  x = ( logit groundColour          -- green .. yellow
      , logit overcolour            -- fraction of NON-russeted skin
      , logit russet                -- only when russet > 0; see below
      , log weight
      , log maxDiameter
      , log (height / maxDiameter)
      )                                                       d ~ 6
```

Being deliberate about this is a design decision in its own right: *features live on a
transformed scale where they are normal*, and every constrained quantity in the model gets there
by log or logit. It is recorded once here rather than rediscovered per feature.

Russet is **zero-inflated**, and the crucial property is that its indicator is *observed* — the
observer records whether there is any russet at all. So the presence layer contributes a
Bernoulli likelihood with a Beta prior per cultivar and adds **no latent variable**, and the
logit-normal coordinate is simply absent (in the phase-parameter sense) when russet is zero.
This is why the parameterisation kills
[the fatal-zeros problem](apple-model-zero-colours-are-fatal.md) rather than relocating it.

Categorical features (`overcolourPattern`, and later shape class) are Dirichlet-categorical per
cultivar and sit outside the Gaussian block entirely.

### Why logit-normal and not Beta for the coverage features

Beta is the obvious candidate for a quantity on [0, 1] and it is the wrong choice here, for three
reasons that are worth recording because the question will come up again:

1. **Beta does not solve the zero problem.** Its density at 0 is 0 when α > 1 and diverges when
   α < 1, finite only at α = 1 exactly. So an observed 0 is as badly behaved under Beta as under a
   logit transform, and zero-inflation is needed either way. Beta is not the escape from
   [the zeros problem](apple-model-zero-colours-are-fatal.md) that it looks like.
2. **A hierarchy of Betas is not conjugate.** Beta has no closed-form conjugate prior for its own
   parameters — this is the same defect as the Dirichlet hyperprior in the old `Main.hs` model, which
   is why that needed an importance sampler. Since every level of this model is a prior over the
   level below, that is disqualifying.
3. **Beta has no additive structure.** The whole model is an additive decomposition — cultivar plus
   tree plus year plus observer plus ripeness. Beta offers no way to add effects; beta *regression*
   does, but only by putting a linear predictor behind a logit link, at which point the hierarchy is
   Gaussian on the logit scale and one has arrived back at logit-normal by a longer route.

Where Beta genuinely belongs: as the prior on a **probability**, not on an extent. The russet
presence indicator is beta-Bernoulli per cultivar, and observer accuracy in the confusion model is a
probability. Both are single numbers that do not carry the hierarchy, which is exactly the case
Beta handles well.

One property of the logit scale worth keeping in mind rather than fighting: constant variance in
logit space is *heteroscedastic* in coverage space, tightest near 0 and 1. That matches how people
actually judge coverage — 0% is easily distinguished from 5%, 50% is not distinguished from 55% — so
the transform is doing useful work rather than merely removing a constraint. If observer precision
should instead be expressed as a notional count, beta-binomial at the *observation* layer is the
alternative, which is the surviving fragment of option A in
[the reformulation options](apple-model-reformulation-options.md); it is available but not needed,
and it would break the conjugate chain upwards.

## The Gaussian hierarchy

```
  mu_0                      ~ N(m_0, S_0)        grand mean: what an apple looks like
  mu_c                      ~ GMRF over pedigree, base N(mu_0, S_cult)
  a_t                       ~ N(0, S_tree)       tree: rootstock, site, management
  w_{y,g}                   ~ N(0, S_year)       year x region weather, optionally smooth in y
  b_o                       ~ N(0, S_bias)       observer bias
  e_s                       ~ N(0, S_src)        source-class bias
  q_k                       ~ N(0, S_prot)       selection-protocol offset for collection k
  r_mat_c, r_sto_c          ~ N(0, S_ripe)       cultivar ripening directions, per clock

  m_i = mu_{z_t} + a_t + w_{y(k),g(t)} + e_{s(i)} + b_{o(i)} + q_{k(i)}
        + age_{t,y} * beta_age
        + durMat_i * r_mat_{z_t}
        + durSto_i * r_sto_{z_t}

  x_i                       ~ N(m_i, S_within)
```

`age`, `durMat` and `durSto` are **observed scalars**; `beta_age`, `r_mat` and `r_sto` are latent
vectors in appearance space.

### Correction 1: ripeness is a regression on observed durations

[The target hierarchy](apple-model-target-hierarchy.md) wrote the observation mean as
`mu_ty + r_i · d_c + b_o` with `r_i` a latent ripeness and `d_c` a latent ripening direction, and
concluded that ripeness "stays conjugate if and only if the dates are recorded". The right
statement is stronger and simpler: **do not introduce a latent ripeness at all.** Once harvest and
examination dates are recorded, the durations *are* the covariates, the only latent is the
per-cultivar direction, and the term is an ordinary Bayesian linear regression — affine in one
latent with an observed coefficient, which is exactly the case `conditionDist` already handles in
its `Normal (Product c (Var v)) (Const variance)` clause. A latent scalar ripeness multiplied by
a latent direction vector would be bilinear and would break conjugacy for no benefit, since the
durations carry the information a latent ripeness was standing in for.

The two clocks stay separate and are not interchangeable. On-tree maturation (bloom → harvest) is
weather-driven and therefore correlated with `w_{y,g}`; post-harvest storage
(harvest → examination) is not, and for a stored winter apple it dominates. Bloom date is itself
weather-dependent and usually unrecorded, so `durMat` will often have to be approximated by the
harvest day-of-year, which is where `Tree.location` becomes load-bearing rather than
nice-to-have: day-of-year means opposite things in the two hemispheres.

### Which effects are crossed

- `w_{y,g}` parents every tree in region *g* in year *y*.
- `b_o` parents every fruit that observer *o* recorded, across all cultivars and trees.
- `e_s` parents every fruit from that source class.
- `mu_c` under a pedigree GMRF is coupled to its relatives' means.

So the design is **crossed at three levels independently**, and no local grouping turns it into a
forest — merging a tree with its year does not help, because the same year node also parents every
other tree in the region. The junction-tree clique is essentially the whole entity latent vector.
Dimension: (10³ trees + 10² cultivars + 10² year×region cells + 10² observers + a handful of
global vectors) × *d* ≈ 6, i.e. **O(10⁴)**. A dense factorisation is O(*d*³) ≈ 10¹² and is not
viable; the structure is genuinely sparse (a fruit touches one tree, one year×region, one
observer, one source, one collection), so the target is a sparse precision representation, which
is Gaussian belief propagation. This is the concrete version of the estimate in
[no supernodes](no-supernodes-for-multiple-parents.md).

### Which covariances are shared

With a few hundred cultivars and thin data per cultivar, almost nothing can be per-cultivar:

- `S_tree` **shared across all cultivars.** Justified rather than merely convenient: trees of a
  cultivar are grafted clones, so tree-to-tree variation is environmental, not genetic — with the
  caveat that sports are clones of their own.
- `S_within` shared, with an optional per-cultivar scalar scale. A full per-cultivar `S_within`
  is what "inherent variability within a cultivar" asks for and is the right long-run target, but
  it is *d*(*d*+1)/2 = 21 parameters per cultivar and will not be identifiable until there are
  many fruit per cultivar. A shared shape with a per-cultivar scale is one parameter each and
  captures most of the effect (some cultivars are simply more variable).
- `S_year`, `S_bias`, `S_src` shared by construction, since each is a distribution over the
  population of years, observers and sources.

## The label sub-model

This is the part that is not Gaussian, and it is where the schema's design pays off.

```
  phi_g                     ~ Dirichlet(alpha)          cultivar frequencies in region g
  z_t                       ~ Categorical(phi_{g(t)})   the TRUE cultivar of tree t
  kappa_o, lambda_o         ~ N(., .)                   observer calibration
  stated_j | z_t, o, q_j    ~ structured confusion
```

### Correction 2: the label latent is per tree, not per fruit

`Judgement` names a `tree`, so the unknown is one categorical per tree, not one indicator per
fruit. That changes the algorithmic conclusion in
[the target hierarchy](apple-model-target-hierarchy.md) and in
[no SMC integration](no-smc-integration.md):

- The count drops from O(10⁵) fruit to O(10³) trees.
- Each `z_t` is informed by *every* fruit from that tree and *every* judgement of it, so its
  posterior is sharp — usually one dominant candidate and a handful of plausible confusions —
  rather than the near-flat per-apple indicator a per-fruit model would give.
- Tree labels are conditionally independent given the shared Gaussian latents, so a collapsed
  scheme that visits one tree at a time is natural.

The earlier claim was that per-apple label error means 2^n joint indicators and therefore that
SMC is mandatory. At tree grain the honest statement is that the model is a **mixture over K^|T|**
and still not conjugate, so some sampling or iteration over the discrete part is unavoidable — but
the algorithm can be a collapsed Gibbs sweep over trees with the Gaussian block marginalized
analytically, and SMC is one way to run that rather than the only one.

### The confusion model must be structured

A full confusion matrix is K² ≈ 10⁵ parameters per pomologist and cannot be estimated. Instead:

```
  accuracy(o, j) = sigmoid( kappa_o + lambda_o * logit(certainty_j) )
  P(stated_j = c' | z_t = c) = accuracy            if c' = c
                            = (1 - accuracy) * sim(c, c') / Z_c   otherwise
```

Two parameters per pomologist, and they are exactly the "make individual bias visible" feature:
`kappa_o` is baseline skill and `lambda_o` is calibration — whether their stated certainty tracks
their actual accuracy. Both are estimable from disagreements between pomologists on the same tree,
which is why deliberately having several people judge the same trees is worth more than the same
effort spread over new trees.

`sim(c, c')` should be **derived from the appearance model** — the Bhattacharyya or
Mahalanobis overlap of the two cultivars' predictive distributions — rather than being a separate
elicited table. That makes confusion a consequence of the model rather than an extra parameter
block, and it gets sports right for free: a sport and its parent have nearly identical means, so
they are predicted to be confused, which is what actually happens. It also introduces a
dependency worth flagging: the discrete part's transition weights depend on the Gaussian part's
current posterior, so the two blocks are coupled and cannot be fitted in one pass.

Reference trees enter as `z_t` **observed**, and they are what identifies everything else.

## Attaching literature to the network

A monograph does not describe a fruit, it describes a cultivar — so it is not an observation with
some terms missing, it is a claim about `mu_c` and about the spread itself. Elicited into the
conjugate family as a location with an effective count (and optionally a spread), it attaches
directly to the cultivar level, bypassing tree, year, collection and ripeness:

```
  elicited claim  --->  mu_c  (+ author bias b_o, + source bias e_s)
      location m, strength kappa  ~ a pseudo-dataset of kappa equivalent fruit
```

Because the sufficient statistics are those of a normal-inverse-gamma update, this needs nothing the
Gaussian hierarchy does not already have, and several descriptions of one cultivar accumulate exactly
as datasets do. The full treatment, including why an interval would be the wrong representation, is
in [descriptions are not observations](cultivar-descriptions-are-not-observations.md).

Three consequences for this network. The literature alone identifies `mu_c` up to the author and
source biases, which is enough to make the model useful before any field data exists — and it is what
carries the rare cultivars. Because a book's `b_o` and `e_s` are confounded with what it describes,
the literature **cannot** by itself separate bias from cultivar mean; only trees judged by several
people, or cultivars described by several independent sources, can do that. And a described *spread*
constrains `S_tree + S_ty + S_within` jointly rather than any one of them, since a book describes what
one typically sees across trees and years — so the decomposition into levels comes only from field
data, and attributing a book's spread to `S_within` would make the model overconfident about new
trees.

## Inference

Conditional on all `z_t`, the entire model is a Gaussian hierarchy with conjugate updates plus
independent Dirichlet-categorical and Beta-Bernoulli blocks, i.e. **exact**. So the scheme is:

1. Marginalize the Gaussian block analytically — delayed sampling's job, and its actual payoff
   here rather than the mere automation of a closed form.
2. Iterate over trees, computing for each the K-way posterior over `z_t` with everything else
   marginalized, either enumerating (feasible at a few hundred cultivars, and the route that
   [exact enumeration](exact-enumeration-of-discrete-latents.md) says needs nothing new) or
   sampling within a collapsed Gibbs sweep.
3. Update the confusion similarities from the refreshed Gaussian posterior and repeat.

Identification of a new tree is then the same computation restricted to one `z_t`, and it returns
a **distribution over cultivars including "other"**, which is what a calibrated probability report
requires.

## Identifiability, which is a data-collection constraint

None of the levels comes for free, and the code should support adding levels as the data allows
and degrading cleanly to fewer rather than assuming the full hierarchy:

- A tree effect needs several fruit from that tree. With one fruit per tree, `a_t` and the
  within-fruit noise are not separable and the level only inflates variance.
- A year×region effect needs several years per region.
- An observer's bias is separable from a cultivar's mean **only if observers cross cultivars**. A
  pomologist who only ever judges Gravensteiner has a bias perfectly confounded with
  Gravensteiner's mean.
- Calibration `lambda_o` needs that observer to have used a *range* of certainties, and to have
  been wrong sometimes.
- Source bias needs cultivars described by more than one source.

## Done when

This document is the specification the port is written against. It is done as a document; what
remains is that each numbered requirement it implies is tracked in
[the requirements](model-v1-delayed-sampling-requirements.md), and that the identifiability list
above is reflected in how collection is organised — several fruit per tree, several judges per
tree, judges crossing cultivars.
