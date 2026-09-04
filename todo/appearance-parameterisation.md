---
status: closed
pkg: [gravensteiner]
closed_by: "c21c393 docs: add the fruit collection form"
provenance: "model-v1-review.md, Tier 3 ('appearance and measurement'), the finding 'The chosen appearance parameterisation.'"
---
# The chosen appearance parameterisation

> **Landed.** `Gravensteiner.Model` now has `Colouration p` with `groundColour :: p Interval`,
> `overcolour :: p Overcolour` and `overcolourPattern :: p OvercolourPattern`, nested inside
> `Appearance p` alongside a zero-inflated `russet :: p Russet` that stays its own field rather
> than joining the record — russet is a texture, not a colouration. The reference units are
> millimetre (height, diameter) and gram (weight). The elicitation protocol — overcolour as a
> fraction of non-russeted skin — is written into `gravensteiner/docs/collection-form.md`'s
> wording, and `Gravensteiner.Model.Scale` carries the logit/log coordinate transforms for every
> feature above, including `logOvercolour` and `logRusset`. The phase parameter this item's body
> assumed is a separate concern: it landed too, and closes with
> [nest-phase-inside-colours](nest-phase-inside-colours.md).
>
> Not landed: `overcolourPattern` is a schema type, a plain enumeration, not yet a node in the
> Bayesian network — that is milestone-6 discrete-node work, tracked in
> [the network design](model-v1-bayesian-network.md).
>
> **This arc overrode this item's own "no structural zeros except russet's".**
> `overcolour :: p Overcolour` now has the same presence layer as russet —
> `NoOvercolour | Overcoloured Interval` — rather than being a bare `Interval`. Three sources bore
> on this and disagreed: this item and
> [the zero-colours diagnosis](apple-model-zero-colours-are-fatal.md) (closed, "Resolved by
> design", "no colour can be a structural zero") on one side,
> [russet is not a colour](russet-is-not-a-colour.md) on the other — the last two closed by the
> *same* commit, `c774c60`, so the contradiction was introduced in one sitting. The maintainer
> settled it on ECPGR Table 17's evidence: "Absent, 0 %" is a named over-colour state with three
> reference cultivars, so Granny Smith has no blush rather than very little skin coverage. The
> shipped schema therefore now **contradicts**
> [the zero-colours diagnosis](apple-model-zero-colours-are-fatal.md)'s "no colour can be a
> structural zero" — that is a decision to meet, not a stale agreement to trust.
>
> The upper end is still open, and ground colour is open at both ends: `logit 1` is reachable for
> `Overcoloured 1` and for `Russeted 1` alike, and `groundColour :: p Interval` has no absent
> constructor at all — nothing in the *type* keeps any of these off 0 or 1. What does is the
> collection form's rule that every recorded value lies strictly inside (0, 1), which is a
> data-collection discipline, not a type guarantee. The round-trip tests added alongside the new
> `test-suite` deliberately stay in the interior of each range and do not exercise this boundary.

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
