# No SMC integration — the paper's whole payoff is unrealised

## Why it matters

Delayed sampling is not presented as an end in itself. Its point is that inside sequential
Monte Carlo it yields *locally optimal proposals* and *automatic Rao-Blackwellization*: each
particle samples from a distribution that already accounts for the observations the analytic
graph could absorb, and the variance of the estimator drops accordingly. That reduction is the
paper's headline result.

Here, `DelayedSamplingT` has only ever been run over `SamplerT` and `WeightedT` — every test is
`sampleIO`/`sampleIOfixed` over `evalDelayedSamplingT`, with `runWeightedT` in between wherever
the model calls `observe`. There is no SMC run, no population, and therefore no evidence of the
benefit the package exists to provide.

## The design question: where the graph lives

`DelayedSamplingT m = ExceptT ErrorTrace (StateT Graph m)`, and monad-bayes has
`newtype PopulationT m a = PopulationT (WeightedT (ListT m) a)`. The two possible orders behave
very differently, and neither is obviously right:

- **`PopulationT (DelayedSamplingT m)`** — the `StateT Graph` sits *below* the list, so all
  particles share one graph. Wrong: the graph is part of a particle's program state, and one
  particle's `realize` would condition another particle's nodes.
- **`DelayedSamplingT (PopulationT m)`** — `StateT` over `ListT` gives each branch its own
  state, which is what is wanted. But resampling then has to act on `(a, Graph)` pairs
  together: `resampleMultinomial` operates on a `PopulationT`, and lifting it through
  `StateT Graph` is exactly the step that must duplicate and discard graphs alongside the
  particles they belong to. A naive `lift`/`hoist` either loses the per-particle graphs or
  resamples values while keeping graphs.

So the deliverable is not "call `smc`" — it is deciding how a resampling step transports the
analytic graph, and making that the documented composition. A useful intermediate check is
that a particle's `Error` must kill that particle rather than the whole population, which the
`ExceptT` position also decides.

Secondary: `observe` needs `MonadMeasure m` and reaches the weight by `lift . score`, so
whatever order is chosen must keep `score` reachable.

Which way the dependency runs with the apple model depends on how far that model goes. In the
*small* version — one prior per cultivar, all observations correctly labelled — the model is fully
conjugate, its cultivar posterior is a finite sum of closed-form predictives, and delayed sampling
never samples anything; SMC would be a demonstration of the Rao-Blackwellization limit below rather
than a requirement. In [the target hierarchy](apple-model-target-hierarchy.md) it is a requirement,
because a per-apple "was this label right" indicator makes the likelihood a mixture over the true
cultivar — not conjugate for the Gaussian means, and with one indicator per apple far too many to
enumerate. Sampling the indicators while keeping the Gaussian hierarchy analytic *is* this item. So
SMC is on the critical path, and the trigger is the label-error model rather than the appearance
model.

## Done when

- A documented transformer stack in which each particle owns its graph and resampling moves
  graphs with particles, with a test that two particles' observations do not affect each
  other's marginals.
- A benchmark on the paper's own state-space example comparing the variance of the estimate
  under plain SMC against SMC with delayed sampling at equal particle counts — the paper's
  Figure 3 comparison. Without a variance measurement the integration cannot be said to work,
  since a wrong integration still produces plausible numbers.
- Ideally, Rao-Blackwellization observable in the numbers: a model whose latent chain is fully
  conjugate should show variance falling to (near) zero, because delayed sampling never has to
  sample it at all.
