# Observation model v1 — review and the additions that matter most

> **Progress:** Tier 1 is implemented in `Gravensteiner.Model` — `Judgement` has `cultivar`/
> `uuid`, `Collection.tree` and `Judgement.pomologist`/`Fruit.observer` are `UUID` references
> rather than by-value embeddings, and a documented tree is recorded as an ordinary `Judgement`
> per the corrected shape below. The last Tier 1 bullet ("book and photo descriptions are
> observations of a different thing") is implemented too, as the source class (`Source`) and
> `Description` entity described in
> [descriptions are not observations](cultivar-descriptions-are-not-observations.md) — see that
> file's own progress note for what of *that* item still remains (the conjugate-update wiring,
> not yet the type-level shapes).
>
> **Correction:** the Tier 1 item below originally suggested a `Provenance` field on `Tree`
> distinguishing documented / attributed / unknown cultivar identity. That was wrong — a nursery
> invoice or a gene test is not exempt from error, it is just another `Judgement`. `Provenance` was
> removed rather than implemented; see
> [judgement-needs-non-person-judges.md](judgement-needs-non-person-judges.md) for the gap this
> leaves (a nursery or lab is not a biological `Person`, and its evidence is not a fruit
> `collection`). Note also that `certainty` is the judge's own **self-reported** subjective
> probability (see the Tier 2 item below), not a trust level we assign — a nursery ledger typically
> states none at all (`certainty :: p Interval`), and how much to trust it is instead something the
> model must learn from data, the same way pomologist accuracy is calibrated via `kappa_o`/`lambda_o`
> rather than read off `certainty` directly.

## Why it matters

`Gravensteiner.Model` is the first real schema: `Person`, `Fruit`, `Collection`, `Tree`,
`Cultivar`, `Judgement`, `UUIDMap`, `Observations`, `Database`, with a higher-kinded phase
parameter marking unobserved fields and a `version` constant for migrations. It replaces
`gravensteiner/app/Main.hs`, which is a precursor and will be deleted.

Two properties of it are already right and worth naming, because most of what follows depends on
them. **The phase parameter is the partial-observation mechanism** the backlog asked for — every
field can independently be missing, which is the normal case rather than an edge case, since a
book gives colour and season while a pomologist in an orchard gives everything. And
**`Judgement` attaches to a tree rather than to a fruit**, which is both pomologically correct
(one identifies the tree, not the apple) and a large statistical improvement over what
[the target hierarchy](apple-model-target-hierarchy.md) assumed — see
[the network design](model-v1-bayesian-network.md) for why.

The additions below are ranked by accuracy gained per unit of schema churn. The ordering is the
point: the first group is not "better modelling", it is the difference between a model that can
be fitted and one that cannot. Since the next step is an online sweep for descriptions and
photos followed by hundreds of collections a year, every one of these is cheaper now than after
data exists in the field.

## Tier 1 — without these the model cannot be fitted at all

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
(see the Tier 2 item below). See
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

## Tier 2 — large gains, cheap

**An examination date distinct from the collection date.** `Collection` has `date` and
`Judgement` has `date`, but `Fruit` has none, so there is no way to express that a fruit was
photographed or described three weeks after it was picked. Storage duration is one of the two
ripeness clocks and for a stored apple it dominates the other; without it, storage change is
attributed to the cultivar. `Tree.planted` already supplies tree age, which is the other free
covariate of this kind.

**`Tree` has no location.** Location matters before it matters for its own sake, because it is
what indexes the year effect: weather is regional, so a single global year effect is a fiction
as soon as collection is not confined to one area. And hemisphere is what makes a bare `Day`
interpretable at all — a March harvest is late-season in one hemisphere and impossible in the
other. Even a coarse region is enough to start, and it costs one field. This is the one Tier-2
item that gets *harder* to retrofit, since location is often unrecoverable after the fact.

**`certainty` should be calibrated, not believed.** *(implemented: `certainty :: p Interval`, with
a haddock stating it is self-reported and not derived from the data)* A self-reported betting
probability is a genuinely rich datum and it is unusual to have it, but people are not calibrated:
some say 90% and are right 70% of the time, others are the reverse. Used directly as *p*(correct)
it imports each pomologist's overconfidence as if it were evidence. Used as a *covariate* through a
two-parameter monotone map per pomologist, it becomes exactly the "make biases visible" feature —
and the map is estimable from disagreements between pomologists on the same tree. Being
`p Interval` rather than `Interval` matters beyond historical/third-party judgements not stating
one: it is also what keeps documented/institutional judgements (see Tier 1's corrected "documented
tree" item above) from having a certainty invented for them that they never actually reported.
The calibration map itself (`kappa_o`/`lambda_o` in
[the network design](model-v1-bayesian-network.md)) is still future modelling work, not yet coded.

**How the fruit were chosen is missing.** A pomologist asked for apples from a tree does not
sample uniformly — they pick typical fruit, or the finest, or whatever is left in October. Each
of those is a different offset in size and colour, and unrecorded it lands in the cultivar mean,
biasing every cultivar towards whatever its observers preferred. One enumerated field per
`Collection` (typical / best / random / everything / unknown) turns an unmodelled bias into an
estimated offset.

**There must be an "other" outcome.** A large share of old orchard and roadside trees are chance
seedlings that belong to no named cultivar at all, and a regional set of a few hundred cannot
contain them by construction. Without an explicit "unnamed seedling / not in the candidate set"
outcome, the model is required to name one of its few hundred for a tree that is none of them,
which is the hallucination failure the old `identify` had and the thing a probability report is
supposed to prevent.

## Tier 3 — appearance and measurement

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

**A minimal measurement set for `Fruit`'s `-- TODO Further properties`.** Weight, maximum
diameter, and the height/diameter ratio. All three are log-normal, all three are supported by
`delayed-sampling` today with no backlog items in the way, all three are cheap in the field (a
scale and a caliper), and for many cultivar pairs they discriminate better than colour does,
which is the most weather- and ripeness-sensitive feature on the list. Shape class (flat /
round / conical) is the natural fourth but needs discrete nodes.

**`Cultivar` needs pedigree and a sport relation.** `alternativeNames` handles synonymy as
strings, but two structural relations are missing. **Pedigree** (`parents :: [UUID]`) enables
the kinship prior that [the target hierarchy](apple-model-target-hierarchy.md) identifies as
the win for rare cultivars, where data is thinnest and a prior does the most work. **Sport-of**
is a different relation and needs to be distinct: a sport is a clonal mutation of its parent,
usually differing in overcolour and almost nothing else, so sports are simultaneously the
easiest pairs to confuse and the ones where the model should *expect* near-identical means with
one systematic difference. A pedigree edge and a sport edge deserve different covariance
structure.

**Nest the phase inside `Colours`.** `Fruit.colours` is `p Colours`, so the colour fields are
missing all together or present all together. A book that says "greenish-yellow" without
mentioning blush is the common case, and under the parameterisation above the fields are
genuinely independent observations. `Colours p` with `groundColour :: p Interval` and so on is
the shape; this is the record-of-variables sugar (R8, done — see
`Control.Monad.Bayes.DelayedSampling.Record`) applied one level down.

**Absence of mention is not absence.** `Maybe` as the phase collapses three distinct situations into
one `Nothing`: measured, could have been recorded and was not, and could not be recorded at all (a
photograph has no weight). They have different likelihood contributions and only the first is
currently expressible. The fix is a purpose-built phase type `Observed`, designed in R12 of
[the requirements](model-v1-delayed-sampling-requirements.md) — where absence of a *feature* is
`Observed 0` rather than a missing value, because "no red on this apple" is an observation.

**And a cultivar description is not an observation at all.** The literature does not describe fruit,
it describes cultivars, so a monograph's "medium-large" is a claim about a *distribution* and
belongs in a separate type with its own conjugate elicitation — see
[descriptions are not observations](cultivar-descriptions-are-not-observations.md). Keeping the two
apart is what lets `Observed` stay simple, since observations are never vague.

**`Interval` repeats a known mistake.** It derives `Num`, `Fractional` and `Floating`, so
`Interval 0.9 + Interval 0.9` is `Interval 1.8` and `exp` leaves the unit interval — the same
defect documented in [the cleanups](apple-model-cleanups.md) for the old `Main.hs` types, now
carried into the new schema. It is recorded here so the finding outlives that file's deletion.
There is also no smart constructor in `Model` at all yet, so nothing is checked; the fix is the
same as before, which is to expose the operations that preserve the invariant instead of
deriving the ones that do not.

## What this does not change

The higher-kinded phase, the UUID-keyed `Database`/`Observations` split, the `version` constant,
and judgement-at-the-tree are all kept as they are. `UUIDMap`'s indexed instances are the right
shape for mapping a record of entities to a record of variables, which is what the port will
need.

## Done when

Each Tier-1 item is either in `Gravensteiner.Model` or has a recorded decision not to be, the
Tier-2 items have decisions before field collection begins (they are cheap now and some are
unrecoverable later), the appearance parameterisation is reflected in the **data-collection form**
as well as the type, and `version` is bumped with a note on what changed.
