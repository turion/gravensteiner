---
status: open
milestone: [6]
size: L
size_evidence: "no cue in source file"
pkg: [gravensteiner]
provenance: "model-v1-review.md, Tier 3 ('appearance and measurement'), the finding '`Cultivar` needs pedigree and a sport relation.'"
---
# `Cultivar` needs pedigree and a sport relation

## Why it matters

**`Cultivar` needs pedigree and a sport relation.** `alternativeNames` handles synonymy as
strings, but two structural relations are missing. **Pedigree** (`parents :: [UUID]`) enables
the kinship prior that [the target hierarchy](apple-model-target-hierarchy.md) identifies as
the win for rare cultivars, where data is thinnest and a prior does the most work. **Sport-of**
is a different relation and needs to be distinct: a sport is a clonal mutation of its parent,
usually differing in overcolour and almost nothing else, so sports are simultaneously the
easiest pairs to confuse and the ones where the model should *expect* near-identical means with
one systematic difference. A pedigree edge and a sport edge deserve different covariance
structure.

## Done when

`Cultivar` gains a pedigree relation (`parents :: [UUID]`) distinct from a sport-of relation,
and the hierarchy's covariance structure treats the two differently — a pedigree edge as the
kinship prior [the target hierarchy](apple-model-target-hierarchy.md) identifies, a sport edge as
an expectation of near-identical means with one systematic (overcolour) difference.
