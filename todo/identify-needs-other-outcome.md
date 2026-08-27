---
status: open
milestone: [4]
size: L
size_evidence: "no cue in source file"
pkg: [gravensteiner, delayed-sampling]
provenance: "model-v1-review.md, Tier 2 (\"large gains, cheap\"), the finding \"There must be an \"other\" outcome.\""
---
# There must be an "other" outcome

## Why it matters

**There must be an "other" outcome.** A large share of old orchard and roadside trees are chance
seedlings that belong to no named cultivar at all, and a regional set of a few hundred cannot
contain them by construction. Without an explicit "unnamed seedling / not in the candidate set"
outcome, the model is required to name one of its few hundred for a tree that is none of them,
which is the hallucination failure the old `identify` had and the thing a probability report is
supposed to prevent.

## Done when

Identification against the regional candidate set includes an explicit "unnamed seedling / not
in the candidate set" outcome rather than being forced to name one of the few hundred candidates,
with a predictive (the prior predictive from `mu_0`, per
[the likelihood question](apple-model-reformulation-options.md)) rather than a made-up one.
