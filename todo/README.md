# Open todos

One file per item. Each states why it matters — citing the paper
([arXiv:1708.07787](https://arxiv.org/abs/1708.07787)) and the relevant function **by name**, never
by line number, since reformatting invalidates line numbers — and what "done" looks like.

## How to read this

Four studies produced these files — a port review of `delayed-sampling`, a review of the paper, a
study of the old apple model in `gravensteiner/app/Main.hs`, and the observation-model-v1 study. The
last one changed the standing of the rest, so the grouping below is by **what the item is for** rather
than by which study found it.

Two documents are the spine. [The network design](model-v1-bayesian-network.md) is the specification
the port is written against, and [the requirements](model-v1-delayed-sampling-requirements.md) numbers
what the machinery must gain to run it, **R1–R15**. Every other item's row below carries its R number
where it has one, and that is the intended reading order: the specification, then a requirement, then
the file that owns it.

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
to be re-collected. Deliberately **not** in it: R1–R4, the multi-parent critical path, which is a
session of its own and which this one exists to give a validated harness to land against.

Items 1-5 are done. Items 6-7 are blocked on [a seed corpus](seed-corpus-needed.md), which does not
exist yet in the workspace.

| | Item | Why it is in this session |
|---|---|---|
| 1 | [The v1 schema review](model-v1-review.md), **Tier 1 only** — *(done)* | The label is missing from `Judgement`, so nothing can be trained or predicted. Tree and `Person` are embedded by value, which silently collapses two levels of the hierarchy. A documented tree (nursery invoice, gene-bank accession) is the only supervision the data will ever contain, and is recorded as an ordinary `Judgement` (trust in it learned from data, not read off a self-reported `certainty`), not a separate provenance field. All cheap now, some unrecoverable once field collection starts. |
| 2 | [Descriptions are not observations](cultivar-descriptions-are-not-observations.md) + R12's `Observed` — *(type-level shapes done; conjugate-update wiring still open)* | Both must exist **before** literature ingestion: the corpus cannot be re-read cheaply, and the adjective vocabulary is part of the data rather than of the reader. |
| 3 | References to a realized node — *(done, item removed — see `graft`'s `Realized _ -> pure ()` case and the regression test in `delayed-sampling/test/DelayedSampling.hs`)* | A verified one-line fix for a reachable failing program. Folding observations against long-lived parameter nodes is exactly the pattern that provokes it. |
| 4 | `Graph` has no child index — *(done, item removed — see `children :: IntMap IntSet` on `Graph`)* | Every operation was O(\|graph\|) without it, and a performance workaround (`deallocateRealized` by hand) was part of the expected API usage. Prerequisite for R11. |
| 5 | Records of variables — R8 — *(done, item removed — see `Control.Monad.Bayes.DelayedSampling.Record`)* | Cheapest item in the backlog: pure sugar over the existing API, no graph changes. With a dozen optional features there are more observation patterns than can be written by hand. |
| 6 | The scalar end-to-end harness — [requirements](model-v1-delayed-sampling-requirements.md), *What is already supported today* — *(blocked on [a seed corpus](seed-corpus-needed.md))* | One feature, one level, labels observed, using only `conditionDist`'s two existing clauses. Every later requirement should be validated against a working pipeline rather than in isolation. |
| 7 | [No evaluation harness](no-evaluation-harness.md) — *(blocked on [a seed corpus](seed-corpus-needed.md))* | Every modelling decision so far rests on an argument, not a measurement, and the seed corpus makes accuracy and calibration measurable for the first time. The held-out split has to be fixed **before** the corpus is used. |

## Shortlist — the most immediate items

Everything unblocked from this session is done. In priority order, what's next:

1. [Closer study of the morphometrics paper](morphometrics-apple-paper.md) — cheapest possible next
   step (reading, not code) and the lead for item 2.
2. [No seed corpus exists yet](seed-corpus-needed.md) — the actual blocker for items 6-7 above.
3. [Conjugate pairs beyond `Normal`](conjugate-pairs-beyond-normal.md), R7's `Gamma`/inverse-gamma —
   needed by item 4.
4. [Descriptions are not observations](cultivar-descriptions-are-not-observations.md)'s remaining
   conjugate-update wiring — needed before literature ingestion, i.e. before the seed corpus can
   actually be used.
5. [`graft` and `prune` scan for all marginalized children](graft-does-not-use-invariant-2.md) —
   cheap now that the child index exists; a correctness/diagnosis fix, not a feature.

## The specification

Read these before picking up anything below; they supersede the sketch-level parts of the
apple-model groups.

| Item | Slated for |
|---|---|
| [The v1 schema review, and the additions that matter most](model-v1-review.md) | now — some additions are unrecoverable after field collection starts |
| [Cultivar descriptions are not fruit observations](cultivar-descriptions-are-not-observations.md) | before literature ingestion |
| [The Bayesian network for observation model v1](model-v1-bayesian-network.md) | the specification the port is written against |
| [What `delayed-sampling` must gain to run it](model-v1-delayed-sampling-requirements.md) | R1–R15; aims everything else |

## The critical path — one joint Gaussian, sparse

R2 → R3 → R4 in order; each is a prerequisite for the next, and R4 decides whether the model runs at
all.

| Item | R | Slated for |
|---|---|---|
| [`Value` has no affine normal form](value-affine-normal-form.md) | R2 | first — R3 and R4 both consume it |
| [`Distribution` and `Value` are scalar-only](vector-valued-variables-and-dirichlet.md) | R3 | the multivariate-normal half; the Dirichlet half has no client |
| [No supernodes, so a node cannot have two parents](no-supernodes-for-multiple-parents.md) | R3, R4 | is the bulk of the model, and must be sparse |
| [Drop `Num` for affine combinators](drop-num-for-affine-combinators.md) | — | with R2, and mechanical; do it with vectors in mind or it is done twice |
| [Marginal and conditional distributions are not distinguished in the type](no-type-level-marginal-conditional.md) | — | with the normal form |

## The discrete path — a label per tree

R5 → R6 → R1. R1's two sub-requirements (scoring K alternatives against one grafted context, and
retracting a conditioning step) are the least certain things in the backlog and are worth prototyping
early.

| Item | R | Slated for |
|---|---|---|
| [Nothing discrete exists, so the cultivar cannot be a node](discrete-nodes-and-dirichlet-categorical.md) | R5 | with the vectors — a categorical's parameter is a vector |
| [A finite discrete latent should be enumerated, not sampled](exact-enumeration-of-discrete-latents.md) | R6 | route (1) is the plan; its per-candidate cost is the constraint |
| [Only `Normal` is usable, and only normal-normal delays](conjugate-pairs-beyond-normal.md) | R7 | beta and gamma are confirmed needs; the rest have no client |
| [No SMC integration](no-smc-integration.md) | — | the paper's payoff; one way to run the collapsed sweep, not the only one |

## Persistence, growth and reporting

| Item | R | Slated for |
|---|---|---|
| [A trained model cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md) | R9, R15 | before there is a fitted state worth keeping |
| [Training must not grow the graph](streaming-training-with-bounded-memory.md) | R10, R11 | the realized-node fix and child index it leaned on are done; inlining on realize is what's left |
| [`Observed` collapses `NotMentioned`/`NotMeasured` into `NotObserved`](mention-vs-not-measured-deferred.md) | R12 | low priority — needs a source class first |
| [Nothing measures whether the model works](no-evaluation-harness.md) | — | with the seed corpus, not after it |
| [No seed corpus exists yet](seed-corpus-needed.md) | — | blocks items 6-7 above — see [the morphometrics paper](morphometrics-apple-paper.md) for a lead |

## Library correctness and hygiene

| Item | Slated for |
|---|---|
| [`graft` and `prune` scan for all marginalized children](graft-does-not-use-invariant-2.md) | the child index it needed is done; the scan itself is not |
| [`observe` takes a `Variable`, not a `Value`](observe-takes-a-variable-not-a-value.md) | single-variable case is cheap now |
| [`pdf`'s catch-all hides unimplemented distributions](pdf-catch-all-hides-unimplemented.md) | later |
| [The paper's examples are only partly covered by tests](missing-paper-examples-as-tests.md) | alongside each fix |
| [Findings from `Main.hs` that outlive it](apple-model-cleanups.md) | `Interval` still derives `Num`; densities should stay in log space |

## Decisions to record, not code to write

| Item | Slated for |
|---|---|
| [Delayed sampling is not transparent to monad-bayes models](not-transparent-to-monad-bayes-models.md) | needs a decision; determines whether the model is written once or twice |
| [`Judgement` cannot yet represent a non-person judge](judgement-needs-non-person-judges.md) | not urgent — extends `Judgement` for nurseries/labs once one needs recording |
| [The paper's own future work](paper-future-work.md) | research-grade — but the non-tree case is where this model lives |
| [Closer study of the morphometrics paper](morphometrics-apple-paper.md) | now more urgent than "before finalising the feature list" — it is the lead for [the missing seed corpus](seed-corpus-needed.md) |

## Decided — kept as the record

Closed, and kept because the reasoning is what justifies the current design. Nothing here is work to
do.

| Item | Outcome |
|---|---|
| [Haskell Bayesian library landscape](haskell-library-landscape.md) | **surveyed** — no Hackage package competes with this project's core infrastructure |
| [Russet is a texture, not a colour](russet-is-not-a-colour.md) | **adopted** — the simplex premise goes, and with it the largest apparent feature gap |
| [The likelihood question](apple-model-reformulation-options.md) | **decided** — option B, on unconstrained scales, with no composition anywhere |
| [The target model is a deep, crossed hierarchy](apple-model-target-hierarchy.md) | **done** — written out formally in the network design; two consequences corrected |
| [Exact zeros in the colour proportions are fatal](apple-model-zero-colours-are-fatal.md) | **done by deletion of the premise** — kept as the diagnosis of the old crash |
| [The planned features, and which are absorbable](apple-features-and-their-conjugate-pairs.md) | the feature-to-requirement index; five features work today |
