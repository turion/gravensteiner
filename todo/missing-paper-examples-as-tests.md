---
status: open
milestone: [6]
size: M
size_evidence: "no cue in source file"
pkg: [delayed-sampling]
---
# The paper's examples are only partly covered by tests

## Why it matters

The test suite is the only evidence that the conjugate updates are right; type-correctness says
nothing about whether a posterior is the posterior. What it currently covers:

- `sample`/`observe` basics, including idempotence of `sample` and the double-observation error;
- the first program of Table 1, asserting the evidence `N(0, 3)` at 3;
- Figure 2, asserting the graph node-by-node before and after the second `graft`;
- `ensureConsistency` — one test per invariant, plus a negative control;
- two statistical acceptance tests: 10 000 observations of a 1-d particle, and a Kalman-filter
  velocity estimate.

## What is missing

**The Table 1 posteriors.** The test forces `x` and `y` and asserts only that they are not
`NaN`; the `-- FIXME` in the test says so. The evidence is checked analytically, the posteriors
are not, so a conditioning bug that leaves the marginal likelihood intact would pass.

**The Kalman filter, undegraded.** The existing test pins the position to a constant because of
[the missing supernodes](no-supernodes-for-multiple-parents.md), so it exercises a
one-parameter model. It also compares a single point estimate; the real check is the posterior
*mean and covariance* against an analytic Kalman filter run over the same observations, at
several time steps rather than only the last.

**I.i.d. observations.** Many children of one parent, grafted in sequence — the case Invariant 2
governs, and where `prune` does its work. The 1-d particle test is close to this, but it observes
each child immediately after creating it, so it never has two marginalized siblings.

**Stochastic branching / spike-and-slab.** A model where the *existence* of a variable depends
on a sampled value. This is the case the paper uses to show that delayed sampling degrades
gracefully — forcing a value early when the program demands it — and nothing here tests that a
forced sample mid-graph leaves the rest of the graph consistent.

**Error paths.** No test asserts that an *unsupported* case is reported rather than silently
mishandled. `UnsupportedConditioning`, `NotMarginal` from `pdf`, `NotImplemented` from
`pdf (Beta …)`, `MultipleParents` from `getParent` (as opposed to from `ensureConsistency`) and
`HasMarginalizedChildren` from `lookupTerminal` are all unexercised. A regression that turned
one of them into a wrong number instead of an error would pass the suite.

## Done when

One test per paper example, with analytic comparisons rather than smoke tests wherever the
posterior is available in closed form; a moment-by-moment comparison against an analytic Kalman
filter; and an `it "throws …"` test for each `Error` constructor that a user can legitimately
provoke.

Worth noting for whoever does this: the two statistical tests use fixed tolerances of
`5 / sqrt n` and are seeded by `sampleIO`, not `sampleIOfixed`, so they are randomised. That is
acceptable for an acceptance test at these sample sizes but should be a conscious choice —
`sampleIOfixed` would make failures reproducible at the cost of hiding tail behaviour.
