---
status: closed
kind: decision
pkg: [gravensteiner]
provenance: "model-v1-review.md's Tier 1 (\"without these the model cannot be fitted at all\"). The document was dissolved into items in 0584870, but Tier 1 was already fully implemented by then, so the dissolution created no item for it. Recorded here instead, since AGENTS.md treats a correction as load-bearing and keeps its file — three live items (judgement-needs-non-person-judges, certainty-needs-calibration, no-evaluation-harness) still cite Tier 1's substance."
closed_by: "621076f Gravensteiner.Model: Tier 1 schema fixes"
---

# Tier 1 of the v1 schema review — implemented, and given its own record

## Why it matters

`model-v1-review.md` ranked its additions "by accuracy gained per unit of schema churn". Tier 1 was
the top rank: without it the model cannot be fitted at all. By the time the document was dissolved
into individual items, every Tier 1 finding was already implemented, so no item was carved out for
it — but three live items still cite its substance, and one of them pointed at "Tier 1's corrected
'documented tree' item above" with no "above" to point at. This file is that missing home.

> **Progress:** Tier 1 is implemented in `Gravensteiner.Model` — `Judgement` has `cultivar`/
> `uuid`, `Collection.tree` and `Judgement.pomologist`/`Fruit.observer` are `UUID` references
> rather than by-value embeddings, and a documented tree is recorded as an ordinary `Judgement`
> per the corrected shape below. The last Tier 1 bullet ("book and photo descriptions are
> observations of a different thing") is implemented too, as the source class (`Source`) and
> `Description` entity described in
> [descriptions are not observations](cultivar-descriptions-are-not-observations.md) — see that
> file's own progress note for what of *that* item still remains (the conjugate-update wiring,
> not yet the type-level shapes).

### Tier 1 — without these the model cannot be fitted at all

**`Judgement` has no cultivar.** *(confirmed)* Its fields are `pomologist`, `tree`,
`collection`, `certainty` and `date` — there is no field naming which cultivar the pomologist
thinks the tree is. The label is the entire quantity the system exists to infer, and it is
absent from the type, so there is nothing to train on and nothing to predict. Needs
`cultivar :: UUID`, keyed into `Database`'s `cultivars`.

**`Collection` embeds its tree by value.** *(confirmed)* `Collection` has `tree :: Tree p`
while `Judgement` has `tree :: UUID`. By-value embedding means two collections from the same
tree are, to the model, two different trees — so the tree level of the hierarchy shares nothing
and collapses into noise, which is the opposite of what a tree level is for. It also puts the
same tree's `planted` year in two places that can disagree. Needs `tree :: UUID`, resolved
against `Observations`'s `trees`.

**`Person` is embedded by value too, with the same consequence for bias.** `Fruit.observer` is
`p Person` and `Judgement.pomologist` is `Person`. An observer's bias is estimable *only* if one
human is one key across every observation they ever make; duplicate `Person` values for the same
human split the evidence and make each copy's bias unidentifiable. `Person` already carries a
`uuid`, and `Database` already has a `people` map, so the reference is available — the records
should use it.

**`Judgement` has no `uuid`.** `Observations.judgements` is a `UUIDMap (Judgement Maybe)`, but
`insert` requires `HasField "uuid" a UUID` and `Judgement` does not have that field, so the one
insertion helper in the module cannot be used for the one map that most needs provenance.
Judgements also need identity for their own sake: they get superseded, retracted, and
disagreed with, and a judgement without a name cannot be referred to in order to be corrected.

**There is no way to say that a tree's cultivar is known.** Truth being latent is correct in
general, but some trees are documented — a nursery invoice, a gene-bank accession, a labelled
tree in a variety collection or mother orchard. Those are the only supervision the data will
ever contain. Without a way to record them, every label in the database is a fallible
pomologist's opinion, the problem is clustering rather than identification, and cultivar means
are pinned by nothing. This is the highest-value single addition after the label itself.
**Corrected shape:** not a separate field on `Tree` — a documented tree is a `Judgement`, since a
nursery or gene-bank record is fallible too, just usually more reliable than a visual opinion. It
is *not* a `Judgement` with `certainty` set near 1: `certainty` is the judge's own self-reported
probability, and a nursery ledger typically states none at all. How much to trust a documented
tree has to be learned from data instead (e.g. from disagreement with other judgements on the
same tree), the same way pomologist accuracy is learned rather than read off `certainty` directly
(see [certainty needs calibration](certainty-needs-calibration.md)). See
[judgement-needs-non-person-judges.md](judgement-needs-non-person-judges.md) for the follow-up
gap this leaves in `Judgement` itself.

**Book and photo descriptions are observations of a different thing.** The seed database will be
built from monographs, pomological literature and websites, and a book does not describe a fruit
from a tree in a year — it describes an idealised cultivar, usually a composite of many fruit,
often with the author's own tendencies baked in. Forcing such a description into `Fruit` inside
a `Collection` requires inventing a `Tree`, which (a) biases the tree level with fictitious
entities, (b) inflates the apparent number of trees per cultivar so the hierarchy becomes
overconfident, and (c) attributes to a year an observation that has no year. The schema needs a
**source class** on observations, and a second kind of observation that attaches to a
`Cultivar` directly. This is the addition that decides whether the seed database can be used at
all, which makes it urgent rather than merely important.

## Done when

**Done.** The reviewer of the todo that carried out the schema fixes confirmed all six findings
above implemented in `Gravensteiner.Model`: `Judgement.cultivar`, `Judgement.tree :: UUID`,
`Fruit.observer :: p UUID`, `Judgement.pomologist`, `Judgement.uuid`, and `Source`/`Description`.
The first five landed in 621076f ("Gravensteiner.Model: Tier 1 schema fixes"); the last —
`Source`/`Description`, for the "book and photo descriptions" bullet — landed separately in
38ab94b ("Gravensteiner.Model: Observed/Description wiring (Step 5)").
