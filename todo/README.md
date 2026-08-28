# Open todos

One file per item. Each states why it matters — citing the paper
([arXiv:1708.07787](https://arxiv.org/abs/1708.07787)) and the relevant function **by name**, never
by line number, since reformatting invalidates line numbers — and what "done" looks like.

## How to read this

Four studies produced these files — a port review of `delayed-sampling`, a review of the paper, a
study of the old apple model in `gravensteiner/app/Main.hs`, and the observation-model-v1 study. The
last one changed the standing of the rest, so the grouping below is by **what the item is for** rather
than by which study found it.

[The network design](model-v1-bayesian-network.md) is the spine — the specification the port is
written against. It used to share that role with a requirements document numbering what the
machinery must gain to run it, R1–R15; that document has been dissolved into the items it
numbered, each carrying its own provenance note where prose was carried over verbatim, so there is
no second document to read alongside it.

Three corrections are worth knowing before reading anything written early, since several files predate
them:

- **`brown` meant russet**, a surface texture rather than a pigment, so the appearance model was never
  a composition. That dissolves the simplex and removes `Dirichlet` from the critical path.
- **The label's grain is the tree, not the apple** — a `Judgement` names a tree — so the discrete
  latent is per tree, O(10³) not O(10⁵). That makes per-tree enumeration inside a collapsed sweep
  viable and demotes SMC from required to one option.
- **Ripeness is not a latent.** Once harvest and examination dates are recorded the durations *are*
  the covariates, so the term is an ordinary regression rather than a bilinear product.

And one thing worth knowing about the port: it is **less blocked than the feature list suggests.**
Five features — weight, size, shape ratios, ground colour and overcolour extent — are scalar
normal-normal chains that work *today*; a finite discrete latent can be enumerated outside the graph
with no new features; and the graph, the transformer and all eight public operations are already
polymorphic in the carrier type. The scalar-only assumption lives in the `Distribution` GADT and its
five interpreters, and nowhere else.

## Next planning session — the schema, and one feature end to end

These seven, in this order, are one coherent session. Together they produce a pipeline that ingests,
fits, reports and is *measured*, on a single appearance feature, against a schema that will not have
to be re-collected. Deliberately **not** in it: the multi-parent critical path, which is a
session of its own and which this one exists to give a validated harness to land against.

Items 1-5 are done. Items 6-7 are blocked on [a seed corpus](seed-corpus-needed.md), which does not
exist yet in the workspace.

| | Item | Why it is in this session |
|---|---|---|
| 1 | The v1 schema review, **Tier 1 only** — *(done)* | The label is missing from `Judgement`, so nothing can be trained or predicted. Tree and `Person` are embedded by value, which silently collapses two levels of the hierarchy. A documented tree (nursery invoice, gene-bank accession) is the only supervision the data will ever contain, and is recorded as an ordinary `Judgement` (trust in it learned from data, not read off a self-reported `certainty`), not a separate provenance field. All cheap now, some unrecoverable once field collection starts. |
| 2 | [Descriptions are not observations](cultivar-descriptions-are-not-observations.md) + [`Observed`'s three-way split](mention-vs-not-measured-deferred.md) — *(type-level shapes done; conjugate-update wiring still open)* | Both must exist **before** literature ingestion: the corpus cannot be re-read cheaply, and the adjective vocabulary is part of the data rather than of the reader. |
| 3 | References to a realized node — *(done, item removed — see `graft`'s `Realized _ -> pure ()` case and the regression test in `delayed-sampling/test/DelayedSampling.hs`)* | A verified one-line fix for a reachable failing program. Folding observations against long-lived parameter nodes is exactly the pattern that provokes it. |
| 4 | `Graph` has no child index — *(done, item removed — see `children :: IntMap IntSet` on `Graph`)* | Every operation was O(\|graph\|) without it, and a performance workaround (`deallocateRealized` by hand) was part of the expected API usage. Prerequisite for [bounded-memory streaming training](streaming-training-with-bounded-memory.md). |
| 5 | Records of variables — *(done, item removed — see `Control.Monad.Bayes.DelayedSampling.Record`)* | Cheapest item in the backlog: pure sugar over the existing API, no graph changes. With a dozen optional features there are more observation patterns than can be written by hand. |
| 6 | The scalar end-to-end harness — see [the likelihood decision](apple-model-reformulation-options.md)'s note that a scalar version is implementable now with `conditionDist`'s existing clauses — *(blocked on [a seed corpus](seed-corpus-needed.md))* | One feature, one level, labels observed, using only `conditionDist`'s two existing clauses. Every later requirement should be validated against a working pipeline rather than in isolation. |
| 7 | [No evaluation harness](no-evaluation-harness.md) — *(blocked on [a seed corpus](seed-corpus-needed.md))* | Every modelling decision so far rests on an argument, not a measurement, and the seed corpus makes accuracy and calibration measurable for the first time. The held-out split has to be fixed **before** the corpus is used. |

<!-- GENERATED INDEX — updated by `todo/check.sh --write-index`; do not hand-edit below this line -->

## Milestone 1

| Item | Size | Packages |
|---|---|---|
| [The chosen appearance parameterisation](appearance-parameterisation.md) | M | gravensteiner |
| [Only `Normal` is usable, and only the normal-normal conjugate pair delays](conjugate-pairs-beyond-normal.md) — The normal-inverse-gamma pair is milestone 1 (the spread half of conjugate elicitation); the beta-Bernoulli/beta-binomial, Dirichlet-categorical and gamma-Poisson/gamma-exponential pairs are milestone 6 only. [vector-valued variables](vector-valued-variables-and-dirichlet.md) and [discrete nodes](discrete-nodes-and-dirichlet-categorical.md) are prerequisites of the Dirichlet-categorical pair only, not of the item as a whole. | L | delayed-sampling |
| [Cultivar descriptions are not fruit observations](cultivar-descriptions-are-not-observations.md) | L | gravensteiner |
| [Closer study of the morphometrics paper](morphometrics-apple-paper.md) | S | gravensteiner |
| [No seed corpus exists yet](seed-corpus-needed.md) | L | gravensteiner |

## Milestone 2

| Item | Size | Packages |
|---|---|---|
| [An examination date distinct from the collection date](examination-date-distinct-from-collection.md) | M | gravensteiner |
| [A minimal measurement set for `Fruit`'s `-- TODO Further properties`](fruit-measurement-set.md) | S | gravensteiner |
| [Nest the phase inside `Colours`](nest-phase-inside-colours.md) | M | gravensteiner |

## Milestone 3

| Item | Size | Packages |
|---|---|---|
| [Findings from `Main.hs` that outlive it](apple-model-cleanups.md) | M | gravensteiner |
| [Nothing measures whether the model works](no-evaluation-harness.md) | L | gravensteiner |

## Milestone 4

| Item | Size | Packages |
|---|---|---|
| [There must be an "other" outcome](identify-needs-other-outcome.md) | L | gravensteiner, delayed-sampling |

## Milestone 5

| Item | Size | Packages |
|---|---|---|
| [`certainty` should be calibrated, not believed](certainty-needs-calibration.md) | L | gravensteiner, delayed-sampling |
| [How the fruit were chosen is missing](fruit-selection-protocol-missing.md) | S | gravensteiner |
| [`Judgement` cannot yet represent a non-person judge](judgement-needs-non-person-judges.md) | L | gravensteiner |
| [`Tree` has no location](tree-has-no-location.md) | S | gravensteiner |

## Milestone 6

| Item | Size | Packages |
|---|---|---|
| [Only `Normal` is usable, and only the normal-normal conjugate pair delays](conjugate-pairs-beyond-normal.md) — The normal-inverse-gamma pair is milestone 1 (the spread half of conjugate elicitation); the beta-Bernoulli/beta-binomial, Dirichlet-categorical and gamma-Poisson/gamma-exponential pairs are milestone 6 only. [vector-valued variables](vector-valued-variables-and-dirichlet.md) and [discrete nodes](discrete-nodes-and-dirichlet-categorical.md) are prerequisites of the Dirichlet-categorical pair only, not of the item as a whole. | L | delayed-sampling |
| [`Cultivar` needs pedigree and a sport relation](cultivar-pedigree-and-sport-relation.md) | L | gravensteiner |
| [A finite discrete latent should be enumerated, not sampled](exact-enumeration-of-discrete-latents.md) | L | delayed-sampling |
| [A trained model cannot be extracted from the graph or loaded back into one](marginals-cannot-be-saved-or-reloaded.md) | L | delayed-sampling, gravensteiner |
| [`Observed` collapses `NotMentioned` and `NotMeasured` into one `NotObserved`](mention-vs-not-measured-deferred.md) | L | delayed-sampling |
| [The paper's examples are only partly covered by tests](missing-paper-examples-as-tests.md) | M | delayed-sampling |
| [The Bayesian network for observation model v1](model-v1-bayesian-network.md) | L | delayed-sampling, gravensteiner |
| [No SMC integration — the paper's whole payoff is unrealised](no-smc-integration.md) | L | delayed-sampling |
| [Delayed sampling is not transparent — models must be rewritten to use it](not-transparent-to-monad-bayes-models.md) | L | delayed-sampling |
| [`observe` takes a `Variable`, not a `Value`](observe-takes-a-variable-not-a-value.md) | L | delayed-sampling |
| [`pdf`'s catch-all hides unimplemented distributions](pdf-catch-all-hides-unimplemented.md) | M | delayed-sampling |
| [Training over many apples must not grow the graph](streaming-training-with-bounded-memory.md) | M | delayed-sampling |
| [`Value` has no affine normal form](value-affine-normal-form.md) | M | delayed-sampling |
| [Drop `Num`/`Fractional` for hand-rolled affine combinators](drop-num-for-affine-combinators.md) | M | delayed-sampling |
| [Marginal and conditional distributions are not distinguished in the type](no-type-level-marginal-conditional.md) | M | delayed-sampling |
| [`Distribution` and `Value` are scalar-only, so there is no vector-valued node](vector-valued-variables-and-dirichlet.md) | L | delayed-sampling |
| [Nothing discrete exists, so the cultivar identity cannot be a node](discrete-nodes-and-dirichlet-categorical.md) | L | delayed-sampling |
| [No supernodes, so a node cannot have two parents — and the Kalman example is degraded](no-supernodes-for-multiple-parents.md) | L | delayed-sampling |
| [A node's parent cannot be selected by a discrete latent](no-stochastic-parent-selection.md) | L | delayed-sampling |

## Milestone 7

| Item | Size | Packages |
|---|---|---|
| [The paper's own future work — research-grade, low priority](paper-future-work.md) | L | delayed-sampling |

## Closed

| Item | Closed by |
|---|---|
| [The planned features, and which of them delayed sampling can absorb](apple-features-and-their-conjugate-pairs.md) | f02577d todo: straighten the backlog into one coherent, sorted plan |
| [The likelihood question, and the decision it reached](apple-model-reformulation-options.md) | f02577d todo: straighten the backlog into one coherent, sorted plan |
| [The target model is a deep, crossed hierarchy — and that reorders this backlog](apple-model-target-hierarchy.md) | c774c60 todo: observation model v1 review, network design, and requirements |
| [Exact zeros in the colour proportions make every density NaN or infinite](apple-model-zero-colours-are-fatal.md) | c774c60 todo: observation model v1 review, network design, and requirements |
| [`atMostOneParent` misses every expression-shaped parent](at-most-one-parent-misses-expression-parents.md) | 8ded243 Fix the local defects found while porting delayed-sampling |
| [Dead code in the graph-mutation helpers](dead-code-in-graph-helpers.md) | 8ded243 Fix the local defects found while porting delayed-sampling |
| [`graft` and `prune` scan for all marginalized children](graft-does-not-use-invariant-2.md) | d7b7171 todo: close graft-does-not-use-invariant-2 |
| [`Graph` has no child index, so every graph operation scans every node](graph-has-no-child-index.md) | 7dc5d7f todo: clean up completed items and align priorities |
| [Haskell Bayesian statistics library landscape](haskell-library-landscape.md) | 0677251 Related work research |
| [Graph invariants are never checked](invariants-unchecked.md) | 8ded243 Fix the local defects found while porting delayed-sampling |
| [No way to build a record of variables, or to observe one partially](records-of-variables-and-partial-observation.md) | 7dc5d7f todo: clean up completed items and align priorities |
| [References to a realized node are handled inconsistently, and `graft` rejects them](references-to-realized-nodes-are-inconsistent.md) | 7dc5d7f todo: clean up completed items and align priorities |
| [Russet is a texture, not a colour — and the simplex premise goes with it](russet-is-not-a-colour.md) | c774c60 todo: observation model v1 review, network design, and requirements |
| [`Num (Value a)` is partial *and* silently order-dependent](value-num-is-partial-and-order-dependent.md) | 8ded243 Fix the local defects found while porting delayed-sampling |
