---
status: open
milestone: [6]
size: L
size_evidence: "A recorded decision on whether (2) or (3) is worth pursuing, with (3)'s combinatorial cost"
pkg: [delayed-sampling]
parent: model-v1-bayesian-network
---
# A finite discrete latent should be enumerated, not sampled

## Why it matters

`identify` wants *p*(cultivar | apple) — a posterior over a finite set. Delayed sampling as
implemented has exactly one way to get a value out of a node: `value` = `graft` then `sample`, and
`sample` ends in `sampleMarginal`, which draws. Drawing a cultivar is throwing away the answer:
that is precisely what `identify` does today, and why it returns `Name` rather than a distribution.

The set is small — a **regional set of a few hundred** cultivars plus an "other" outcome — and the
summand is available in closed form given the Gaussian block, so the posterior should be computed by
summation. This is the paper's spike-and-slab / stochastic-branching case taken one step
further: the paper's point is that delayed sampling *degrades gracefully* by forcing a sample when
the program demands a value, whereas here the right answer is not to force it at all.

## Three routes, in increasing ambition

**(1) Enumerate outside the graph.** Run one `DelayedSamplingT` computation per cultivar, take each
run's evidence from `runWeightedT`, and combine with the prior weights by hand:
*p*(*c* | tree) ∝ π_c · *Z*_c. This needs **no new features at all**, which is what makes it the right
first port. Cost: the graph is rebuilt per candidate, so shared structure is recomputed *k* times, and
there is no way to condition the shared parent on the mixture.

**This route is now the plan, and its cost is the binding constraint rather than a footnote.**
[The network design](model-v1-bayesian-network.md) puts one categorical latent per *tree* over a
regional set of a few hundred cultivars, and enumerating it is exactly this route — so it is on the
critical path, not merely a first step. But *k* is a few hundred, and the shared structure being
recomputed is the entire crossed Gaussian block, so rebuilding it *k* times per tree would be the
dominant cost of the whole algorithm. The requirement that follows is to graft the shared context
**once** and score *k* alternatives against it; it is the first sub-requirement of
[a node's parent cannot be selected by a discrete latent](no-stochastic-parent-selection.md), and it
is the difference between an algorithm that runs and one that does not.

**(2) Run over an enumeration base monad.** `DelayedSamplingT (Enumerator)` would make the discrete
choice exact and keep everything in one computation. There is a real obstacle worth knowing before
trying: monad-bayes' `Enumerator` implements only `bernoulli` and `categorical`, with
`random = error "Infinitely supported random variables not supported in Enumerator"`. Since
`MonadDistribution`'s `normal` is derived from `random`, *any* call to `sampleMarginal` on a
`Normal` blows up. Under a fully conjugate model nothing continuous is ever sampled, so this could
work — but it works by accident, and it fails with an `error` rather than an `Error` the moment a
non-conjugate part is added. If this route is taken, it needs a guard that turns "a continuous node
was forced" into a diagnosable failure. A `WeightedT`-over-`Enumerator` stack also has to be
reconciled with the transformer-order question in
[no SMC integration](no-smc-integration.md), which is the same question with `PopulationT` in place
of `Enumerator`.

**(3) Marginalize the discrete node inside the graph.** A genuine `Categorical` node whose child is
conditioned by summing over its values — delayed sampling extended to exact discrete
marginalization, i.e. the mixture is kept analytic in the same way a conjugate pair is. This is the
principled version and the only one that lets the *shared* hierarchical parent be conditioned on
the cultivar mixture rather than per-branch. It is also a genuine extension of the paper, whose
graph carries only conjugate parent-child pairs, so it belongs next to
[the paper's own future work](paper-future-work.md) on non-tree tractable structures. Note the cost
that route (1) hides: a marginalized mixture node has *k* components, and a chain of *m* such nodes
has *k^m* unless components are collapsed, which is why this is not simply better than (1).

## Done when

- Route (1) exists and is documented as the supported way to handle a finite discrete latent, with
  a test that the enumerated posterior over a two-component mixture matches an analytically
  computed one.
- A recorded decision on whether (2) or (3) is worth pursuing, with (3)'s combinatorial cost
  stated.
- Identification returns normalized weights over cultivars including "other", not a draw — see
  [reformulation options](apple-model-reformulation-options.md), change 1.

## From the v1 requirements document (R6)

| # | Requirement | Needed for | Status |
|---|---|---|---|
| R6 | Exact enumeration of a discrete latent with the Gaussian part marginalized | the per-tree K-way posterior | [enumeration](exact-enumeration-of-discrete-latents.md) |
