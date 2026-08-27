---
status: open
milestone: [1]
size: M
size_evidence: "no cue in source file"
pkg: [gravensteiner]
provenance: "model-v1-review.md, Tier 3 ('appearance and measurement'), the finding 'The chosen appearance parameterisation.'"
---
# The chosen appearance parameterisation

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

## Done when

`Colours` is restructured to `groundColour` / `overcolour` / `overcolourPattern` / `russet`
as described above, and the elicitation protocol (ask for overcolour as a fraction of
non-russeted skin, to keep the model conjugate) is written into the data-collection form's
wording, not only into a comment.
