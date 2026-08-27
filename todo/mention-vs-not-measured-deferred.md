---
status: open
milestone: [6]
size: L
size_evidence: "no cue in source file"
pkg: [delayed-sampling]
---
# `Observed` collapses `NotMentioned` and `NotMeasured` into one `NotObserved`

Low priority — revisit once a source class exists to condition the mention likelihood on.

## Why it matters

R12 (`model-v1-delayed-sampling-requirements.md`) specifies three cases for `Observed` because they
cost different things in the likelihood: `NotMeasured` is free — an ungrafted variable, which is
exactly what delayed sampling already does — while `NotMentioned` is informative and should
contribute a Bernoulli on a per-source "mention indicator", conditioned on the latent value. That
needs a source class — something that knows, per literature source or per observer, how likely it
is to mention a given feature when present — which does not exist yet.

`Control.Monad.Bayes.DelayedSampling.Record`'s `observeField` therefore had two branches,
`NotMentioned` and `NotMeasured`, that did exactly the same thing (`pure ()`). A distinction that
every call site treats identically is worse than not having it: it is exactly the confusion that
prompted this file. `Observed` is collapsed to `Observed a | NotObserved` until there is a second
behaviour to distinguish.

## Shape of the fix

Reintroduce the three-way split (or a `NotObserved SourceClass` argument) once a source class with
a mention-propensity parameter exists, and give `observeField`'s absent-case branch on `NotMentioned`
the Bernoulli contribution R12 describes. Until then, anything recorded under `NotObserved` has
thrown away the "why absent" fact — the caution about capturing this at data entry (R8, done —
see `Control.Monad.Bayes.DelayedSampling.Record`) still applies; it is just not enforced by the
type today.

## Done when

- A source class exists with a mention-propensity parameter.
- `Observed` regains a way to distinguish "could have been recorded but wasn't" from "the source
  cannot produce this field", and `observeField`'s `NotMentioned` case contributes the
  mention-indicator Bernoulli.
- Call sites that ingest data under today's two-way `Observed` are revisited to capture the
  distinction where the source is known, rather than losing it permanently.

## From the v1 model review (Tier 3)

**Absence of mention is not absence.** `Maybe` as the phase collapses three distinct situations into
one `Nothing`: measured, could have been recorded and was not, and could not be recorded at all (a
photograph has no weight). They have different likelihood contributions and only the first is
currently expressible. The fix is a purpose-built phase type `Observed`, designed in R12 of
[the requirements](model-v1-delayed-sampling-requirements.md) — where absence of a *feature* is
`Observed 0` rather than a missing value, because "no red on this apple" is an observation.
