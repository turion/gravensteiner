# Nothing discrete exists, so the cultivar identity cannot be a node

## Why it matters

The quantity the whole program is about — *which cultivar is this?* — is a categorical latent, and
`delayed-sampling` has no discrete distribution whatsoever. `Distribution`'s three constructors all
carry `Double`; there is no Bernoulli, categorical, binomial, multinomial or Poisson, so
`identify`'s answer cannot be represented in the graph at all. Nor can `frequency`, which its own
FIXME says should be "Dirichlet weights over all sorts", i.e. a Dirichlet parent of a categorical
child.

Two distinct discrete needs, and they are not the same size:

**A categorical over cultivars** with a Dirichlet prior on its weights. Conjugate, standard, and
the predictive is (α_c + *n*_c) / Σ(α + *n*) — a single division. Needed by every version of the
model.

**A discrete child of a colour node.** Under
[option A](apple-model-reformulation-options.md) the observation itself is multinomial counts, so
Dirichlet-multinomial conjugacy is the *likelihood*, not a side dish. Under option B the
structural-zero layer needs a Bernoulli per colour with a Beta prior — which is also the pair that
would finally make the existing `Beta` constructor useful rather than decorative
([only `Normal` is usable](conjugate-pairs-beyond-normal.md)).

## What it actually costs

Less than the scalar-only framing suggests. As noted in
[vector-valued variables](vector-valued-variables-and-dirichlet.md), the graph, the transformer and
all seven public operations are polymorphic in the carrier; `pdf` returns `Log Double`, so a pmf
needs no new type. Adding `Categorical :: Value (Vector Double) -> Distribution Int` requires:

- a `pdf` clause — indexing a weight vector, trivial;
- a `sampleMarginal` clause — `lift $ categorical v`, already imported via
  `Control.Monad.Bayes.Class`;
- an `isTerminalDistribution` clause;
- `marginalizeDistribution`/`conditionDist` clauses for the Dirichlet pair, which is where the real
  work is and which depends on vector-valued variables landing first.

So the *prerequisite* is vectors, not discreteness: a categorical's parameter is a weight vector,
and a Dirichlet parent is vector-valued. The two items should be scheduled together.

One carrier question worth settling early: should the categorical be `Distribution Int` with the
caller maintaining an index-to-`Name` mapping, or `Distribution Name` with the weights carried
alongside? The latter is friendlier at the `identify` boundary and costs nothing — `Name` already
derives `Eq`, `Ord` and `Show`, and `Typeable` is free — but it makes the weight vector's
correspondence to the value set implicit, which is the kind of thing that silently desynchronises.
A `Categorical :: f (Value Double) -> Distribution (Key f)` over the same shape functor discussed
in the vectors item would settle both at once.

## Done when

- `Categorical` (and, for option A, `Multinomial`) in the GADT with clauses in all five
  interpreters.
- Dirichlet-categorical and Dirichlet-multinomial `marginalizeDistribution`/`conditionDist`
  clauses, with a statistical test that observed counts move the posterior weights the right way.
- A test that a categorical node can be `observe`d, since `observe` needs `pdf` and a pmf at an
  impossible outcome is 0, i.e. `score 0` — which kills the particle. Whether that is the desired
  behaviour, or whether an impossible observation should be an `Error`, is a decision to record.
- Note that sampling the categorical is usually the *wrong* thing to do with it; see
  [exact enumeration of discrete latents](exact-enumeration-of-discrete-latents.md).
