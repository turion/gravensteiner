# Collection form: recording one fruit's appearance

This is the form a pomologist reads with an apple in hand. It covers **one fruit**. Answer the
eight questions in the order given — several later questions refer back to an earlier answer, and
answering out of order leaves you guessing at a definition you have not read yet.

Anchors below (named cultivars, percentage bands) are quoted from UPOV TG/14/10 and the 2022 ECPGR
Malus descriptors — see each question for the specific table. Where a state has no reference
cultivar in that source, this form says so rather than supplying one: an invented anchor would
poison a corpus that cannot be re-read cheaply.

> **No answer on this form is ever exactly 0 or 1.** A feature that is genuinely absent (no
> russet, no blush) is recorded by choosing "absent" — a separate answer, not the number 0 — and
> every other recorded value lies **strictly inside (0, 1)**, however close to 1 the judged
> reading is. This is not a stylistic preference: the numbers feed a logit, and `logit(0)` and
> `logit(1)` are both infinite. Writing 0 or 1 anywhere below does not mean "very little" or "all
> of it", it silently breaks the record.

## 1. Is there any russet at all?

Russet is a dull, brown, rough, corky patch on the skin (UPOV *Ad. 35*) — it is a texture that
*overlays* colour, not a shade of it. Look at the stalk cavity, the cheeks and the eye basin
together.

**Answer: yes / no.**

- **No** → skip question 2 and go straight to question 3. Non-russeted skin is the whole fruit's
  surface.
- **Yes** → answer question 2.

## 2. If there is russet, how much?

Judge the overall coverage — cheeks, eye basin and stalk cavity together, as one average — and
record the number you judge, strictly inside (0, 1). Use these bands (ECPGR Table 20, "Overall
russet coverage") as calibration anchors to judge against, not as a set of six permitted answers:

| You see about... | ECPGR band | Anchor | Reference cultivar |
|---|---|---|---|
| 1-10 % | Very low | 0.055 | |
| 11-25 % | Low | 0.18 | Cox's Orange Pippin |
| around 50 % | Medium | 0.50 | Boskoop |
| around 75 % | High | 0.75 | Zabergäu Renette |
| over 90 % | Very high | 0.95 | Egremont Russet, Canada Gris, Gris Braibant, Brownlee's Russet |

("Absent, 0 %" is Lobo's band — but that answer belongs to question 1, not here; a "no" at
question 1 already recorded it.)

## 3. How much of the *non-russeted* skin carries a red blush (overcolour)?

**Ask this as a fraction of the skin that is not russeted — not of the whole apple.** If question
1/2 found russet, exclude that russeted area first and judge the blush against what remains.

*Why worded this way:* neither ECPGR nor UPOV states what its over-colour percentage scale is a
share *of* — the non-russeted-skin reading below is **this project's own convention**, not a
reading of either standard. The reason for choosing it is that the visible red you would see over
the whole fruit is roughly `blush × (1 − russet)` — a product of two unknown quantities, which
breaks the statistical model that this corpus feeds. Asking for the fraction of non-russeted skin
instead keeps the two readings independent, so the constraint that keeps the model tractable is
answered here, in the question's wording, rather than left for someone downstream to fix.

Judge against the same calibration anchors as question 2 (ECPGR Table 17, "Over colour coverage"),
and record the number you judge, strictly inside (0, 1):

| You see about... | ECPGR band | Anchor | Reference cultivar |
|---|---|---|---|
| (none) | Absent, 0 % | *absent* (see below) | Granny Smith |
| 1-10 % | Very low | 0.055 | |
| 11-25 % | Low | 0.18 | Cox's Orange Pippin |
| around 50 % | Medium | 0.50 | |
| around 75 % | High | 0.75 | Spartan |
| over 90 % | Very high | 0.95 | |

If there is no blush at all, record **absent** as its own answer (mirroring question 1), not 0 %.
If question 4 does not apply (see below), the reason is that this question was answered "absent".

**Warning — it is not known what the anchors above are a share of.** Neither ECPGR nor UPOV states
what its over-colour or russet percentage scales are relative to, so it is not known whether the
bands and cultivars above (both here and in question 2) already reflect non-russeted skin
(matching this question) or the whole fruit (not matching it) — there is no published precedent
either way. On a barely russeted cultivar this is close enough not to matter — Granny Smith and
Spartan are safe anchors as given. On a russeted one it might not be: **Cox's Orange Pippin** is
*both* Low russet (11-25 %) *and* Low overcolour (11-25 %), which makes it exactly the cultivar
where a mismatch between the two readings would matter most — but with both standards silent,
there is no known direction to correct it in. Judge the actual apple in front of you against the
bands above as calibration only; do not read "Cox's Orange Pippin = Low" as telling you the number
for this question — no correction is computable from these anchors.

## 4. If question 3 was not "absent": what pattern is the blush?

Skip this question entirely if question 3 was answered "absent" — a fruit with no blush has no
pattern, and none of the eight states below means "no blush".

Choose one of the eight states (the union of UPOV char. 33 and ECPGR Table 19's vocabulary):

| State | Reference cultivar |
|---|---|
| Only solid flush | Richard Delicious (ECPGR); Bay 3484, Red Jonaprince, Telamon (UPOV) |
| Solid flush with stripes | **Gravensteiner** (ECPGR); Charlotte, Cripps Pink, among others (UPOV) |
| Only stripes (no flush) | Dülmener Rosenapfel |
| Flushed and mottled | Dalinbel, Scifresh |
| Flushed, striped and mottled | Elstar, Pinova, Topaz, among others |
| Marbled | Karneval |
| Mottled | *no reference cultivar in the source — none is given here either* |
| Washed out | *no reference cultivar in the source — none is given here either* |

## 5. What is the ground colour, read off the base skin?

Read this **only off the base skin — the patch of skin that is neither russeted (question 1/2) nor
blushed (question 3/4)**. This is why it is asked last of the four colouration questions: you
cannot pick out the base skin until you know which parts of the skin are excluded as russeted or
blushed.

Judge where the base skin sits on the green-to-yellow axis, against ECPGR Table 16's six ordered
states as calibration anchors, and record the number you judge, strictly inside (0, 1):

| Axis band | ECPGR state | Anchor | Reference cultivar |
|---|---|---|---|
| 1 | Green | 0.08 | Granny Smith |
| 2 | Whitish green | 0.25 | |
| 3 | Green yellow | 0.42 | Cox's Orange Pippin |
| 4 | Whitish yellow | 0.58 | |
| 5 | Yellow | 0.75 | Golden Delicious |
| 6 | (Yellow) - Orange | **0.92** | |

This table is duplicated in `Gravensteiner.Model`'s `groundColour` haddock, because a Haddock
comment cannot render a markdown table — if you change one copy, change the other to match.

The state names and cultivar anchors in this table are **ECPGR Table 16's**; the six [0,1] numbers
are **this project's own convention** of equal bands, positioned at their midpoints — ECPGR
publishes no numbers for them, only the six ordered states. These are calibration anchors, not a
set of permitted answers: record the number you actually judge, not the nearest anchor. Note the
axis above runs green-to-yellow, the **reverse** of ECPGR's own numbering (Table 16 numbers Yellow
1 and Green 5) — never cite an ECPGR state number against one of the axis-band numbers in the left
column.

Two cases where the base skin is not a straightforward green-yellow judgement:

- **An orange base skin** ("(Yellow) - Orange" in ECPGR) is **band 6, anchored at 0.92 — past
  yellow on the same axis, not off it in some other direction**. Record the number you judge near
  the top of the axis, not the phrase "at the yellow end".
- **A fruit blushed so completely that the base skin cannot be seen at all** (what UPOV calls
  ground colour "not visible") is not a value on this axis. Record ground colour as **not
  observed** for this fruit. Writing 1.0 because "it looked very yellow where visible" is exactly
  the mistake this form exists to prevent — it is not on the axis, and 1.0 is a poisoned value
  regardless.

## 6. Height, in millimetres

Measure at the tallest point of the flesh — not along the polar axis through the stalk cavity and
calyx basin (UPOV TG/14 characteristic 23). Record in **millimetres**, e.g. `58`.

## 7. Diameter, in millimetres

Measure at the widest point — the fruit's equator (UPOV TG/14 characteristic 24). "Widest" names
where you take the caliper reading, not a maximum over repeated measurements. Record in
**millimetres**, e.g. `71`.

## 8. Weight, in grams

Weigh the whole fruit on a kitchen scale. Record in **grams**, e.g. `142`.

## Reading from a published description

A monograph or other published description is a fixed text, not a live observer — you cannot ask
it a follow-up question, so the "costs nothing" argument behind question 3's wording does not
apply when *ingesting* one. Two things follow:

- **A source that says nothing about a feature has not said the feature is absent.** A monograph
  silent about russet has not stated the fruit is unrusseted, and one silent about Deckfarbe
  (blush) has not stated the fruit is unblushed — `Russet` and `Overcolour` have no way to express
  "not mentioned" versus "stated absent", but `Description`'s fields use
  `Described a = DescribedAs (Elicited a) | NotDescribed`, which does. **Record silence as
  `NotDescribed` for both fields.** Recording it as `NotRusseted` or `NoOvercolour` instead feeds a
  positive claim of absence into the presence layer that the model treats as an observed
  Bernoulli outcome — the source never made that claim. Use `NotRusseted` / `NoOvercolour` only
  when the source explicitly states the fruit carries no russet, or no blush.
- **Published blush figures are recorded as stated, with no conversion.** This project's reading is
  that a monograph scoring "the amount of over colour on the skin" already means the visible,
  non-russeted skin question 3 asks a live observer for — the same convention this form uses
  throughout. That is **this project's reading of an unstated convention, not a sourced fact**:
  neither ECPGR nor UPOV says what a published over-colour or russet percentage is relative to (see
  question 3's warning above). Recording as stated also fits a fact the standards *do* state: ECPGR
  §2.13 scores russet as an average over "at least 12 representative fruits", so a published figure
  is a **population average**, not a single fruit's reading — a population can legitimately show
  more total coverage than any one fruit in it, so there is no per-fruit bound for a stated figure
  to violate, and nothing to convert or clamp.
