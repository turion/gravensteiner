# Nothing measures whether the model works

> **Blocked:** on [a seed corpus](seed-corpus-needed.md), which does not exist yet in the
> workspace — see that file for what's needed before this one can proceed.

## Why it matters

Every modelling decision recorded in this backlog was made on statistical reasoning alone. The
appearance parameterisation, logit-normal over Beta, ripeness as a covariate, the label latent at the
tree, the structured confusion model, the elicited pseudo-count cap — all of them are arguments, and
not one of them has been checked against data. That was unavoidable while the training set was three
apples and three cultivars: with one apple per cultivar, *every* candidate model fits perfectly, so
the data could not discriminate between them even in principle.

The seed database changes that, and it is the reason this is now a live item rather than a
housekeeping note. Once there are descriptions and photographs for a few hundred cultivars, held-out
identification accuracy and calibration become measurable **for the first time**, and they are the
only things that can arbitrate between the choices above. Building the harness at the same time as the
corpus is much cheaper than retrofitting it, because the held-out split has to be decided before the
data is used rather than after.

`gravensteiner.cabal` also still has **no `test-suite` stanza at all** — only an `executable` — so
there is currently no place to put even a unit test, let alone an evaluation.

## Three distinct things, and they need separate treatment

**Unit correctness.** Does the code compute what the model says? For a conjugate model the sharpest
available test is not a statistical one: reload a fitted state, observe more, and check the posterior
equals a single-session fit over all the observations
([marginals cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md) makes this the
round-trip test, and it compares two *exact* computations rather than a sample against a tolerance).
`delayed-sampling`'s own suite is the model for style here; `gravensteiner` has nothing.

**Accuracy.** Given a held-out collection, is the true cultivar ranked first — and if not, is it in
the top *k*? Ranking is the right frame rather than a single guess, because the system's purpose is to
narrow a pomologist's candidate list, and top-5 accuracy on a few-hundred candidate set is the number
that says whether it is useful.

**Calibration, which is the one that will fail.** The stated goal is to report a *probability* that
an identification is right, and a model can rank well while being badly overconfident. That is the
expected failure mode here for three independent reasons, each of which the harness should be able to
see separately:

- a per-cultivar posterior fitted to a handful of fruit has almost no spread;
- for a literature-only cultivar the elicited prior *is* the model, so the reported uncertainty is
  whatever `kappa_max` makes it — the check named in
  [descriptions are not observations](cultivar-descriptions-are-not-observations.md);
- a described spread constrains `S_tree + S_ty + S_within` jointly, so attributing it to within-fruit
  noise alone understates variation across new trees
  ([the network design](model-v1-bayesian-network.md)).

A reliability diagram over held-out judgements, bucketed by reported probability, is the measurement.
It should be reported **separately for literature-only and field-measured cultivars**, since those
have different failure modes and averaging them hides both.

## What the data structure makes possible for free

Two evaluations fall out of the schema rather than needing extra collection, and they are worth
naming because they are unusually cheap:

- **Reference trees are ground truth.** A documented tree — nursery invoice, gene-bank accession,
  variety collection — has `z_t` observed via an ordinary `Judgement` (trust in it learned from
  data rather than read off a self-reported `certainty` — see
  [the schema review](model-v1-review.md)'s Tier 2 item), so held-out reference trees give a real
  accuracy figure without a pomologist adjudicating anything. This is one more reason the ability
  to record such a tree, from Tier 1 of [the review](model-v1-review.md), is the highest-value
  single addition.
- **Disagreements between pomologists on the same tree** are what identify `kappa_o` and
  `lambda_o`, and they are also a free consistency check: a model whose confusion structure is right
  should predict *which* pairs of cultivars get confused, not merely how often. Predicted confusion
  pairs versus observed ones is a sharper test of the appearance model than accuracy is, because
  `sim(c, c')` is derived from the Gaussian posterior rather than fitted.

## The sequencing consequence

The reformulation decision, and everything downstream of it, was made without evidence and should be
**re-checked** rather than treated as settled once there is enough data to hold any out. That is not a
reason to delay the port — the arguments are the best available now — but it is a reason for the
harness to exist before the corpus is large, so that the re-check is a command rather than a project.

## Done when

- `gravensteiner` has a `test-suite`, containing at least the conjugate round-trip equality test and
  a finite-weights check over the seed corpus.
- A held-out split is defined and recorded *before* the corpus is used for fitting, with reference
  trees reserved as ground truth.
- Top-1 and top-*k* accuracy are reported on that split, and a reliability diagram is reported
  separately for literature-only and field-measured cultivars.
- Predicted confusion pairs are compared against observed pomologist disagreements.
- The decisions in [the reformulation options](apple-model-reformulation-options.md) and
  [the network design](model-v1-bayesian-network.md) are re-examined against those numbers, and the
  outcome recorded here.
