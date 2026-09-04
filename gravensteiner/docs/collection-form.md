# Collection form: recording one fruit's appearance

This is the form a pomologist reads with an apple in hand. It covers **one fruit**. Answer the
eight questions in the order given — several later questions refer back to an earlier answer, and
answering out of order leaves you guessing at a definition you have not read yet.

Anchors below (named cultivars, percentage bands) are quoted from this arc's research notes on the
descriptor standards (`research/descriptor-standards.md`), which are themselves quoted from UPOV
TG/14/10 and the 2022 ECPGR Malus descriptors — see each question for the specific table. Where a
state has no reference cultivar in that source, this form says so rather than supplying one: an
invented anchor would poison a corpus that cannot be re-read cheaply.

> **No answer on this form is ever exactly 0 or 1.** A feature that is genuinely absent (no
> russet, no blush) is recorded by choosing "absent" — a separate answer, not the number 0 — and
> the top band of a percentage scale is recorded at its midpoint, never at 1.0. This is not a
> stylistic preference: the numbers feed a logit, and `logit(0)` and `logit(1)` are both infinite.
> Writing 0 or 1 anywhere below does not mean "very little" or "all of it", it silently breaks the
> record.

## 1. Is there any russet at all?

Russet is a dull, brown, rough, corky patch on the skin (UPOV *Ad. 35*) — it is a texture that
*overlays* colour, not a shade of it. Look at the stalk cavity, the cheeks and the eye basin
together.

**Answer: yes / no.**

- **No** → skip question 2 and go straight to question 3. Non-russeted skin is the whole fruit's
  surface.
- **Yes** → answer question 2.

## 2. If there is russet, how much?

Judge the overall coverage — cheeks, eye basin and stalk cavity together, as one average — against
these bands (ECPGR Table 20, "Overall russet coverage"), and record the band's **midpoint**, not a
raw percentage:

| You see about... | ECPGR band | Records as | Anchor |
|---|---|---|---|
| 1-10 % | Very low | 0.055 | |
| 11-25 % | Low | 0.18 | Cox's Orange Pippin |
| around 50 % | Medium | 0.50 | Boskoop |
| around 75 % | High | 0.75 | Zabergäu Renette |
| over 90 % | Very high | 0.95 (never 1.0) | Egremont Russet, Canada Gris, Gris Braibant, Brownlee's Russet |

("Absent, 0 %" is Lobo's band — but that answer belongs to question 1, not here; a "no" at
question 1 already recorded it.)

## 3. How much of the *non-russeted* skin carries a red blush (overcolour)?

**Ask this as a fraction of the skin that is not russeted — not of the whole apple.** If question
1/2 found russet, exclude that russeted area first and judge the blush against what remains.

*Why worded this way:* the visible red you would see over the whole fruit is roughly
`blush × (1 − russet)` — a product of two unknown quantities, which breaks the statistical model
that this corpus feeds. Asking for the fraction of non-russeted skin instead keeps the two
readings independent, so the constraint that keeps the model tractable is answered here, in the
question's wording, rather than left for someone downstream to fix.

Judge against the same percentage bands as question 2 (ECPGR Table 17, "Over colour coverage"),
recording the midpoint:

| You see about... | ECPGR band | Records as | Anchor |
|---|---|---|---|
| (none) | Absent, 0 % | *absent* (see below) | Granny Smith |
| 1-10 % | Very low | 0.055 | |
| 11-25 % | Low | 0.18 | Cox's Orange Pippin |
| around 50 % | Medium | 0.50 | |
| around 75 % | High | 0.75 | Spartan |
| over 90 % | Very high | 0.95 (never 1.0) | |

If there is no blush at all, record **absent** as its own answer (mirroring question 1), not 0 %.
If question 4 does not apply (see below), the reason is that this question was answered "absent".

**Warning — the anchors above are whole-fruit percentages, and this question is not.** ECPGR's
bands and cultivars (both here and in question 2) are shares *of the whole fruit*; there is no
published precedent for scoring blush against non-russeted skin only, which is why question 3
asks for it explicitly rather than assuming it. On a barely russeted cultivar the two are close
enough not to matter — Granny Smith and Spartan are safe anchors as given. On a russeted one they
are not: **Cox's Orange Pippin** is ECPGR's own example of this — it is *both* Low russet (11-25 %
of the whole fruit) *and* Low overcolour (11-25 % of the whole fruit), so once you exclude its
russeted 11-25 %, its blush covers a larger share of what is left than "11-25 %" suggests. Judge
the actual apple in front of you against the bands above; do not read "Cox's Orange Pippin = Low"
as telling you the number for this question — no corrected figure for Cox is available (the
maintainer has been asked for one).

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
states, and record the band's **midpoint** — never 0 or 1:

| Axis band | ECPGR state | Records as | Anchor |
|---|---|---|---|
| 1 | Green | 0.08 | Granny Smith |
| 2 | Whitish green | 0.25 | |
| 3 | Green yellow | 0.42 | Cox's Orange Pippin |
| 4 | Whitish yellow | 0.58 | |
| 5 | Yellow | 0.75 | Golden Delicious |
| 6 | (Yellow) - Orange | **0.92** | |

The state names and cultivar anchors in this table are **ECPGR Table 16's**; the six [0,1] numbers
are **this project's own convention** of equal bands recorded at their midpoints — ECPGR publishes
no numbers for them, only the six ordered states. Note the axis above runs green-to-yellow, the
**reverse** of ECPGR's own numbering (Table 16 numbers Yellow 1 and Green 5) — never cite an ECPGR
state number against one of the axis-band numbers in the left column.

Two cases where the base skin is not a straightforward green-yellow judgement:

- **An orange base skin** ("(Yellow) - Orange" in ECPGR) is still on this axis, past the yellow
  end rather than off it in some other direction — record it as **band 6, 0.92**, the number, not
  the phrase "at the yellow end".
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

*(Provisional — the maintainer has confirmed a live observer can judge blush against non-russeted
skin reliably, so the form above is settled; the conversion below, for turning a published
whole-fruit figure into this form's fields, has not yet been confirmed and should be revisited.)*

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
- **Published blush figures are stated over the whole fruit**, the same denominator ECPGR itself
  uses, not over the non-russeted skin question 3 above asks for. To bring a stated whole-fruit
  blush fraction `b` and a stated russet fraction `r` onto this form's scale, divide:
  `overcolour = b / (1 - r)`. Flag this as a **conversion, not a measurement** — it amplifies
  whatever guess went into `b` and `r`, and it amplifies it most exactly where russet is largest
  (as `r → 1`, `1 - r → 0`).
  - **If the result exceeds 1, record `NotDescribed`, not a clamp to 1.** A whole-fruit blush
    larger than the whole non-russeted share means the two stated figures do not fit together —
    clamping would manufacture a maximum-confidence answer out of a conversion that has just shown
    itself to be out of range. This happens for real cultivars: Boskoop's own russet anchor is
    around 50 %, so any published whole-fruit blush above 50 % overshoots for Boskoop.
