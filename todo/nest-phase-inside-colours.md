---
status: open
milestone: [2]
size: M
size_evidence: "no cue in source file"
pkg: [gravensteiner]
needs: [appearance-parameterisation]
provenance: "model-v1-review.md, Tier 3 ('appearance and measurement'), the finding 'Nest the phase inside `Colours`.'"
---
# Nest the phase inside `Colours`

## Why it matters

**Nest the phase inside `Colours`.** `Fruit.colours` is `p Colours`, so the colour fields are
missing all together or present all together. A book that says "greenish-yellow" without
mentioning blush is the common case, and under the parameterisation above the fields are
genuinely independent observations. `Colours p` with `groundColour :: p Interval` and so on is
the shape; this is the
[record-of-variables sugar](records-of-variables-and-partial-observation.md) (done — see
`Control.Monad.Bayes.DelayedSampling.Record`) applied one level down.

## Done when

`Colours` takes a phase parameter (`groundColour :: p Interval` and so on, once
[the appearance parameterisation](appearance-parameterisation.md) lands), so a book that gives
ground colour without mentioning blush can be recorded as such instead of the whole `Colours`
value being all-or-nothing.
