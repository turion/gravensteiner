---
status: open
milestone: [6]
size: L
size_evidence: "stepping stone towards the apple model; it is the bulk of it."
pkg: [delayed-sampling]
needs: [vector-valued-variables-and-dirichlet]
parent: model-v1-bayesian-network
---
# No supernodes, so a node cannot have two parents — and the Kalman example is degraded

## Why it matters

Delayed sampling's graph must be a forest: at most one parent per node. `getParent` throws
`MultipleParents` for anything else, and `ensureConsistency`'s `atMostOneParent` reports it
up front. The paper is explicit that this is a limitation of the *representation*, not of the
method, and its answer is **supernodes**: when an expression mentions two variables, merge
them into a single node carrying their joint distribution, "much like the junction tree
algorithm".

This is not a hypothetical gap. It is why the flagship example in the test suite is
**degraded rather than merely simplified**:

```haskell
        -- pos <- normal 0 1 -- FIXME Can't deal with multiple parents yet
        let pos = 0
        vel <- normal 0 1
        …
            -- let mu = Var posVar + Const t * Var velVar
```

The Kalman test pins the position to a constant and estimates only the velocity, so what it
verifies is a one-parameter model, not a Kalman filter. The paper's entire Rao-Blackwellization
story is about exactly the state-space models that need `pos + t · vel`.

It is also the hard blocker for the apple model, and not one blocker in one place but the shape of
every level: in [the network design](model-v1-bayesian-network.md) a fruit's mean is a sum of **six**
latent vectors plus two regression terms — cultivar, tree, year × region, observer, source class and
collection protocol. Worse, that design is **crossed** rather than nested — one year effect parents
every tree in a region, one observer parents fruit of every cultivar — so no local merge yields a
forest at all, and the clique is essentially the whole latent vector. Item 1 below is therefore not a
stepping stone towards the apple model; it is the bulk of it.

## Why the merge is forced, not a convenience

Marginalization over independent parents is trivial —
`x + y ~ N(μx + μy, σx² + σy²)` — so it is tempting to keep `x` and `y` as separate nodes.
Conditioning is what breaks: given an observation downstream of `x + y`, the posterior over
the pair is *correlated*, and two separate `Normal` marginals cannot represent a correlation.
Keeping them apart would silently discard precisely the information delayed sampling exists
to retain. The longer version of this argument, with the full case analysis of which
`Var`-plus-`Var` expressions are tractable, is in
[dropping `Num` for affine combinators](drop-num-for-affine-combinators.md).

## What exists

`Normal2 :: Value (Double, Double) -> Distribution Double` is a stub in the `Distribution`
GADT. `subst` and `getParents` handle it, and nothing else does: no `pdf`, no
`marginalizeDistribution`, no `conditionDist`, `sampleMarginal` falls through to
`throw NotMarginal`, and `isTerminalDistribution` returns `False` for it unconditionally. A
pair is also the wrong shape in the long run — the supernode's dimension grows with the number
of variables an expression mentions.

## Done when

In dependency order:

1. A vector-valued node: multivariate normal with a mean vector and a covariance matrix, and
   the corresponding `pdf`, `sampleMarginal`, `marginalizeDistribution` and `conditionDist`.
   This needs `Value` to express an affine map from a vector-valued variable to a scalar,
   i.e. a row vector against the supernode — the linear-combination representation from
   [`Value` has no affine normal form](value-affine-normal-form.md).
2. A merge step: when `initialize` (or `graft`) meets an expression mentioning several
   variables, replace those nodes by one supernode holding their joint, rewriting every
   reference. `atMostOneParent` then becomes a check that no node references two *supernodes*.
3. The Kalman test restored to both latent variables, checked against an analytic 2-d Kalman
   filter's posterior mean and covariance rather than a single point estimate.

Expect the junction-tree cost model along with the analogy: the supernode's covariance is
dense and its dimension is the size of the merged clique, so a model that couples everything
degrades to no delay at all. That is the correct behaviour, but it should be measurable
rather than surprising.

And the apple model sits at that extreme rather than near it, so sparsity is not an optimisation to
add later. This is no longer a caution but a **requirement with a number attached**:
[the network design](model-v1-bayesian-network.md) totals the entity latent vector at **O(10⁴)** for
a regional model (10³ trees, 10² cultivars, 10² year×region cells, 10² observers, appearance
*d* ≈ 6), which puts a dense solve at ~10¹² flops and ~10⁸ doubles of covariance — not viable, and
worsening with every tree added. The structure is genuinely sparse, since a fruit touches one tree,
one year × region, one observer, one source and one collection, so the useful target is a sparse
precision representation with a fill-reducing ordering, i.e. Gaussian belief propagation, rather than
a dense covariance that happens to be large.

This is a requirement with the representational consequence spelled out below: information form
makes conditioning cheap and marginalization expensive, the opposite of the covariance form
`conditionDist` uses today, and this model conditions constantly during training and marginalizes
only to serve — which is why the resolution is to fit in information form and extract a small
moment-form cache for serving (see
[marginals cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md)) rather than to
pick one.

## From the v1 requirements document (R4)

This is the part that decides whether the model runs at all. Because the design is crossed at three
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
  Gibbs sweeps (see
  [a node's parent cannot be selected by a discrete latent](no-stochastic-parent-selection.md)), and
  grows the latent vector as trees and observers appear (see
  [streaming training with bounded memory](streaming-training-with-bounded-memory.md)). All three are
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
from the cache.** That also settles what
[marginals cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md) persists — the serving cache is the artifact worth
shipping, the information-form state is the thing worth checkpointing, and they are not the same
object. And the "other" outcome comes free, since its predictive is the prior predictive from
`mu_0` with the full between-cultivar covariance added.
