---
status: closed
pkg: [gravensteiner]
closed_by: "891d41d Model: replace Colours with a per-field phased Colouration"
provenance: "model-v1-review.md, Tier 3 ('appearance and measurement'), the finding 'Nest the phase inside `Colours`.'"
---
# Nest the phase inside `Colours`

> **Landed**, in the same revision as
> [the chosen appearance parameterisation](appearance-parameterisation.md): `Gravensteiner.Model`
> now has `Colouration p` with `groundColour :: p Interval`, `overcolour :: p Overcolour` and
> `overcolourPattern :: p OvercolourPattern`, so a book that gives ground colour without
> mentioning blush is recordable as such rather than the whole record being all-or-nothing.

## Why it matters

**Nest the phase inside `Colouration`.** `Fruit.colours` is `p Colouration`, so the colour fields are
missing all together or present all together. A book that says "greenish-yellow" without
mentioning blush is the common case, and under the parameterisation above the fields are
genuinely independent observations. `Colouration p` with `groundColour :: p Interval` and so on is
the shape; this is the
[record-of-variables sugar](records-of-variables-and-partial-observation.md) (done — see
`Control.Monad.Bayes.DelayedSampling.Record`) applied one level down.

## Done when

`Colouration` takes a phase parameter (`groundColour :: p Interval` and so on, once
[the appearance parameterisation](appearance-parameterisation.md) lands), so a book that gives
ground colour without mentioning blush can be recorded as such instead of the whole `Colouration`
value being all-or-nothing.
