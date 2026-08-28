---
status: open
milestone: [1]
size: M
size_evidence: "no cue in source file"
pkg: [gravensteiner]
provenance: "model-v1-review.md, Tier 3 ('appearance and measurement'), the finding 'The chosen appearance parameterisation.'"
---
# The chosen appearance parameterisation

## Why it matters

**The chosen appearance parameterisation.** `Colours` currently has `yellow`, `red` and `green`
with `russet` separate — already the improvement that [russet is not a colour](russet-is-not-a-colour.md)
argued for. The remaining step is to stop treating the three as a composition:

- `groundColour` — one number, 0 = green to 1 = yellow. This is the ripening readout as well as
  an identifying feature, so it does double duty.
- `overcolour` — the extent of red blush, **as a fraction of non-russeted skin**.
- `overcolourPattern` — blush / striped / flecked / mottled, a categorical.
- `russet` — extent, zero-inflated, and the zero is genuinely common.

Two coordinates instead of three constrained numbers, no simplex to enforce, no structural zeros
except russet's, and both continuous coordinates are logit-normal and therefore work in
`delayed-sampling` today. The elicitation constraint is not a detail: visible red is
approximately blush × (1 − russet), which is *bilinear* in two latents and breaks conjugacy, so
asking the observer for the fraction of non-russeted skin pushes a modelling constraint into the
collection form where it costs nothing. That belongs in the form's wording, not in a comment.

The measurement set (`Shape`'s `height` and `diameter`, and `Appearance`'s `weight`) enters the
model the same way: as logs of dimensionless quantities, e.g. `h /~ milli metre` rather than a raw
`Length`. Three coordinates are in play, and the unit choice touches two of them independently.
The length unit (`h /~ milli metre`, `d /~ milli metre`) shifts the length scale coordinate — the
sum of the two log lengths, roughly — and leaves the shape coordinate, their difference, invariant,
since the reference unit cancels between the two logs. The mass unit (`w /~ gram`) shifts
log-weight's own prior location, which is a third coordinate and not part of either. Which
reference unit each measurement uses is still an open choice.

## Done when

`Colours` is restructured to `groundColour` / `overcolour` / `overcolourPattern` / `russet`
as described above, and the elicitation protocol (ask for overcolour as a fraction of
non-russeted skin, to keep the model conjugate) is written into the data-collection form's
wording, not only into a comment. A reference unit is chosen for each of the length and mass
coordinates — millimetres or centimetres, grams or kilograms — because a log-normal prior's
location cannot be written down without one.
