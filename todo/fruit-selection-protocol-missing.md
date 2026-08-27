---
status: open
milestone: [5]
size: S
size_evidence: "One enumerated field per"
pkg: [gravensteiner]
provenance: "model-v1-review.md, Tier 2 (\"large gains, cheap\"), the finding \"How the fruit were chosen is missing.\""
---
# How the fruit were chosen is missing

**How the fruit were chosen is missing.** A pomologist asked for apples from a tree does not
sample uniformly — they pick typical fruit, or the finest, or whatever is left in October. Each
of those is a different offset in size and colour, and unrecorded it lands in the cultivar mean,
biasing every cultivar towards whatever its observers preferred. One enumerated field per
`Collection` (typical / best / random / everything / unknown) turns an unmodelled bias into an
estimated offset.

## Done when

`Collection` carries an enumerated "how chosen" field (typical / best / random / everything /
unknown), recorded before field collection begins.
