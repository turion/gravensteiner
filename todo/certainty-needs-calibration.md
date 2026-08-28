---
status: open
milestone: [5]
size: L
size_evidence: "is still future modelling work, not yet coded."
pkg: [gravensteiner, delayed-sampling]
provenance: "model-v1-review.md, Tier 2 (\"large gains, cheap\"), the finding \"`certainty` should be calibrated, not believed.\""
---
# `certainty` should be calibrated, not believed

## Why it matters

**`certainty` should be calibrated, not believed.** *(implemented: `certainty :: p Interval`, with
a haddock stating it is self-reported and not derived from the data)* A self-reported betting
probability is a genuinely rich datum and it is unusual to have it, but people are not calibrated:
some say 90% and are right 70% of the time, others are the reverse. Used directly as *p*(correct)
it imports each pomologist's overconfidence as if it were evidence. Used as a *covariate* through a
two-parameter monotone map per pomologist, it becomes exactly the "make biases visible" feature —
and the map is estimable from disagreements between pomologists on the same tree. Being
`p Interval` rather than `Interval` matters beyond historical/third-party judgements not stating
one: it is also what keeps documented/institutional judgements (see
[Tier 1's corrected "documented tree" item](model-v1-review-tier-1.md)) from having a certainty
invented for them that they never actually reported.
The calibration map itself (`kappa_o`/`lambda_o` in
[the network design](model-v1-bayesian-network.md)) is still future modelling work, not yet coded.

## Done when

The calibration map (`kappa_o`/`lambda_o` in [the network design](model-v1-bayesian-network.md))
is implemented and estimable from disagreements between pomologists on the same tree, so a
pomologist's self-reported `certainty` is used as a covariate through their own two-parameter
monotone map rather than as `p`(correct) directly.
