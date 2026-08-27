---
status: open
milestone: [5]
size: S
size_evidence: "Even a coarse region is enough to start, and it costs one field."
pkg: [gravensteiner]
provenance: "model-v1-review.md, Tier 2 (\"large gains, cheap\"), the finding \"`Tree` has no location.\""
---
# `Tree` has no location

## Why it matters

**`Tree` has no location.** Location matters before it matters for its own sake, because it is
what indexes the year effect: weather is regional, so a single global year effect is a fiction
as soon as collection is not confined to one area. And hemisphere is what makes a bare `Day`
interpretable at all — a March harvest is late-season in one hemisphere and impossible in the
other. Even a coarse region is enough to start, and it costs one field. This is the one Tier-2
item that gets *harder* to retrofit, since location is often unrecoverable after the fact.

## Done when

`Tree` carries a coarse location field (region and hemisphere are the minimum, since hemisphere
is what makes a bare `Day` interpretable), recorded before field collection begins.
