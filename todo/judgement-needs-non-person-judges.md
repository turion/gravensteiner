---
status: open
milestone: [5]
size: L
size_evidence: "likely a sum type or a second table, not a new field on"
pkg: [gravensteiner]
---
# `Judgement` cannot yet represent a non-person judge

## Why it matters

[Tier 1 of the schema review](model-v1-review-tier-1.md) originally suggested a `Provenance` field
on `Tree` distinguishing documented / attributed / unknown cultivar identity, as if a nursery
invoice or a gene-bank accession were a different kind of fact than a pomologist's opinion. It is
not: a nursery mislabels stock, and even a gene test carries a small but non-negligible risk of
laboratory error (e.g. mixing up two samples). Every source of cultivar identity is fallible, and
that is exactly what `Judgement` already models. So `Provenance` was removed rather than added; a
documented tree is a `Judgement`, not a distinct type. It is *not* a `Judgement` with `certainty`
set near 1 either — `certainty` is the judge's own self-reported subjective probability (see
[certainty needs calibration](certainty-needs-calibration.md)), and a nursery ledger or gene-bank record
typically states none at all (`certainty :: p Interval`). How much to trust a documented tree has
to be learned from data instead, the same way pomologist accuracy is learned rather than assumed.
See `Gravensteiner.Model`'s `Judgement` for the corrected documentation.

That correction exposes a real gap, though: `Judgement.pomologist :: UUID` is keyed into
`Database`'s `people`, and `Person` has `name`/`email`/`phone` — fields that assume a biological
person. A nursery or a testing lab is a legal person, not a biological one, and forcing it through
`Person` today means either inventing a fake individual or leaving fields blank. Similarly,
`Judgement.collection :: p UUID` assumes the evidence is a fruit collection, which holds for a
pomologist's field examination but not for a gene test or a decades-old planting record, whose
evidence is a lab assay or a grafting lineage rather than fruit.

## Shape of the fix

- Distinguish judge kinds (person / institution / lab) instead of forcing every judge through
  `Database.people`'s `Person` type — likely a sum type or a second table, not a new field on
  `Person`, since a nursery has no `email`/`phone` in the individual sense.
- Add a way to describe evidence that is not a fruit collection (e.g. "grafted from tree/source
  X", "gene marker profile from lab Y") alongside `collection`, so a `Judgement` can point at
  whichever evidence its judge actually produced.
- `certainty` (the judge's own self-report) stays the single field for that, regardless of judge
  kind — that is what keeps documented, attributed, gene-tested and pomologist-opined identities
  all first-class members of the same `Judgement` type rather than a parallel hierarchy that needs
  its own handling everywhere `Judgement` is used. How much to actually *trust* each judge kind
  (as opposed to what they self-report) still has to be learned from data, and extending the
  `kappa_o`/`lambda_o` per-pomologist calibration in
  [the network design](model-v1-bayesian-network.md) to per-institution/per-lab calibration is a
  natural place to do that once non-person judges exist.

## Done when

`Judgement` (or a generalisation of it) can represent a nursery's planting record and a gene
test result without misusing `Person` or `collection`, and existing pomologist judgements are
unaffected.
