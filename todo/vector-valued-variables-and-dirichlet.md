---
status: open
milestone: [6]
size: L
size_evidence: "## Design questions to settle first"
pkg: [delayed-sampling]
needs: [value-affine-normal-form]
---
# `Distribution` and `Value` are scalar-only, so there is no vector-valued node

> **The multivariate-normal half is R3 and load-bearing; the Dirichlet half has no client.** Read
> this file with that split in mind — it was written when the appearance model was a simplex and the
> Dirichlet looked like the point. The appearance **vector** is what needs a vector carrier now:
> *d* ≈ 6 coordinates at every level of the hierarchy, per
> [the network design](model-v1-bayesian-network.md). A `Dirichlet` node would only be wanted for
> `phi_g`, the cultivar frequencies, which is a small block outside the Gaussian hierarchy and could
> equally be maintained outside the graph.

## Why it matters

Every constructor of `Distribution` produces a `Distribution Double`:

```haskell
  Normal  :: Value Double -> Value Double -> Distribution Double
  Normal2 :: Value (Double, Double) -> Distribution Double
  Beta    :: Value Double -> Value Double -> Distribution Double
```

`Normal2` takes a *pair-valued parameter* but still yields a scalar — it is the beginning of a
two-parent supernode, not a bivariate distribution (see
[no supernodes](no-supernodes-for-multiple-parents.md)). Nothing in the module produces a vector, so
neither a multivariate normal nor a `Dirichlet` can be written down at all.

**Why the multivariate normal is unavoidable.** Two independent reasons, and neither is about the
simplex. The appearance coordinates are genuinely correlated — ground colour and overcolour both move
with ripening, so a diagonal approximation throws away real information — and the crossed hierarchy
makes one large joint Gaussian the whole representation rather than a refinement of it. The scheduling
lives in [no supernodes](no-supernodes-for-multiple-parents.md), which is the same requirement seen
from the graph side; this file is the carrier-and-`Value` side of it.

**The graph machinery is not the obstacle.** `initialize`, `graft`, `prune`, `marginalize`,
`realize`, `sample`, `value` and `observe` are all polymorphic in the carrier type, constrained
only by `Typeable a, Show a, Eq a`; `Graph`/`SomeNode`/`ResolvedVariable` are existentially
wrapped and carrier-agnostic; `pdf` already returns `Log Double`, which is as happy with a
multivariate density as with a scalar one. The scalar assumption lives in exactly two places: the
`Distribution` GADT, and the five functions that interpret it (`pdf`, `sampleMarginal`,
`isTerminalDistribution`, `marginalizeDistribution`, `conditionDist`). That is a much smaller
blast radius than it first appears.

**`Value` is the harder half.** Its numeric constructors are

```haskell
  Sum     :: (Typeable a, Eq a, Show a, Num a) => Value a -> Value a -> Value a
  Product :: (Typeable a, Eq a, Show a, Num a) => a -> Value a -> Value a
```

Both demand `Num a` on the carrier, and `Product` scales by an `a` — the *same* type as the value.
For a vector carrier that is wrong twice over: a vector type has no sensible `(*)`, `abs` or
`signum` (defining them to satisfy the class is exactly the invariant-breaking `deriving Num` that
[the model cleanups](apple-model-cleanups.md) complains about on `Interval`), and the operation
actually wanted is scaling a vector by a *scalar*, or multiplying it by a *matrix*, neither of
which `Product :: a -> Value a -> Value a` can express. So the affine operations for vectors are
vector addition, scalar scaling and matrix–vector multiplication, and a `Num`-based encoding
supports none of them properly. This is the same conclusion as
[drop `Num` for affine combinators](drop-num-for-affine-combinators.md), reached from the vector
side: that item should be done with vectors in mind, or it will have to be done twice.

## Design questions to settle first

**What is the carrier?** Three options, in increasing Haskell-specificity:

- `Data.Vector Double` — simplest, dimensions checked at runtime, mismatches become `Error`s.
- A statically sized vector (`Vec n Double`) — dimension errors become type errors, at the cost of
  threading `n` through `Distribution`, `Node`, `Variable` and the existential wrappers, where the
  `Typeable` constraints will make it unpleasant.
- **A shape functor**: `Dirichlet :: f (Value Double) -> Distribution (f Double)` for a
  `Representable`/`Traversable` `f`. Then `Colours` itself is the carrier — `Distribution Colours`
  — the field names survive into the graph, `Show` output stays readable, and this composes
  directly with the record-of-variables sugar (R8, done — see
  `Control.Monad.Bayes.DelayedSampling.Record`), which wants a record-of-`Variable` layer anyway.
  Most attractive, least conventional.

**Covariance representation.** A multivariate normal needs a covariance *matrix* in a slot where
`Normal` has a `Value Double` variance. The existing normal-normal `conditionDist` computes with
`1 / variance`; the vector version needs a precision matrix and a solve, so `statistics`/`hmatrix`
enters the dependency set, or a hand-rolled Cholesky at the per-node dimension, which stays small —
*d* ≈ 6 per entity. Note that this decision is *not* the same as R4's: R4 is about the sparse joint
over O(10⁴) entity latents, whereas this is about one node's own *d*×*d* block, and a dense solve is
entirely appropriate at that size. Deciding it also settles whether the variance slot may be a
variable at all — see [marginal vs conditional](no-type-level-marginal-conditional.md).

## Done when

- A carrier decision recorded, and `Distribution` reshaped so a vector-valued constructor is
  expressible without `Num` on the carrier.
- `Dirichlet` and/or `MultivariateNormal` with clauses in all five interpreters, not just `subst`
  and `getParents` — `Normal2` is the cautionary example of a constructor that exists in name only
  and is therefore worse than absent, since it reads as available.
- A statistical acceptance test in the style of the existing ones: many draws from a known
  Dirichlet or multivariate normal, asserting the posterior recovers the truth within a stated
  tolerance. For a Dirichlet, the natural test is that a Dirichlet-multinomial posterior recovers
  known proportions from counts.
