# `Distribution` and `Value` are scalar-only, so a `Dirichlet` node is inexpressible

## Why it matters

The colour simplex is irreducibly four-dimensional, and every constructor of `Distribution`
produces a `Distribution Double`:

```haskell
  Normal  :: Value Double -> Value Double -> Distribution Double
  Normal2 :: Value (Double, Double) -> Distribution Double
  Beta    :: Value Double -> Value Double -> Distribution Double
```

`Normal2` takes a *pair-valued parameter* but still yields a scalar — it is the beginning of a
two-parent supernode, not a bivariate distribution (see
[no supernodes](no-supernodes-for-multiple-parents.md)). Nothing in the module produces a vector,
so neither `Dirichlet` (option A of
[the reformulation options](apple-model-reformulation-options.md)) nor a multivariate normal
(option B) can be written down.

**The two halves have diverged in priority.** Once [russet is recognised as a texture rather than a
colour](russet-is-not-a-colour.md) the appearance model is three scalars in [0, 1] and no simplex
remains, so `Dirichlet` loses its client — while the **multivariate normal** becomes unavoidable,
both for the joint covariance of those scalars (ground colour and overcolour extent move together
with ripeness) and for [the target hierarchy](apple-model-target-hierarchy.md), whose crossed design
makes one large joint Gaussian the whole representation. Read the multivariate-normal parts of this
item as load-bearing and the Dirichlet parts as speculative, and see
[no supernodes](no-supernodes-for-multiple-parents.md), which is where the multivariate normal is
actually scheduled.

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
  directly with [records of variables](records-of-variables-and-partial-observation.md), which
  wants a record-of-`Variable` layer anyway. Most attractive, least conventional.

**Covariance representation.** A multivariate normal needs a covariance *matrix* in a slot where
`Normal` has a `Value Double` variance. The existing normal-normal `conditionDist` computes with
`1 / variance`; the vector version needs a precision matrix and a solve, so `statistics`/`hmatrix`
enters the dependency set, or a hand-rolled Cholesky for small fixed dimensions (4 colours, so
small is realistic). Deciding this also settles whether the variance slot may be a variable at all
— see [marginal vs conditional](no-type-level-marginal-conditional.md).

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
