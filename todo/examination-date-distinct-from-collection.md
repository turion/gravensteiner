---
status: open
milestone: [2]
size: M
size_evidence: "no cue in source file"
pkg: [gravensteiner]
provenance: "model-v1-review.md, Tier 2 (\"large gains, cheap\"), the finding \"An examination date distinct from the collection date.\""
---
# An examination date distinct from the collection date

## Why it matters

**An examination date distinct from the collection date.** `Collection` has `date` and
`Judgement` has `date`, but `Fruit` has none, so there is no way to express that a fruit was
photographed or described three weeks after it was picked. Storage duration is one of the two
ripeness clocks and for a stored apple it dominates the other; without it, storage change is
attributed to the cultivar. `Tree.planted` already supplies tree age, which is the other free
covariate of this kind.

## Done when

`Fruit` carries a field for the date it was examined, distinct from `Collection.date`, so
storage duration between collection and examination can be computed as one of the two ripeness
clocks (the other being `Tree.planted`).
