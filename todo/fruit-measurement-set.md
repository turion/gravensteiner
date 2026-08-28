---
status: closed
pkg: [gravensteiner]
provenance: "model-v1-review.md, Tier 3 ('appearance and measurement'), the finding 'A minimal measurement set for `Fruit`'s `-- TODO Further properties`.'"
closed_by: "9e3deff Model: hold the caliper's and the scale's readings on Appearance"
---
# A minimal measurement set for `Fruit`'s `-- TODO Further properties`

> **Closed, with departures.** `Gravensteiner.Model` now carries `Shape`'s `height` and `diameter`
> and `Appearance`'s `weight`, but not exactly as this item asked for, and one finding did not
> belong here at all:
>
> - **The ratio is not a stored field.** `Shape p` holds `height` and `diameter`, both
>   `p (Length Double)`; `heightDiameterRatio :: (Functor p, Applicative p) => Shape p -> p
>   (Dimensionless Double)` computes `height / diameter` from them. Storing all three would make
>   them a deterministic triple, and a likelihood that treats them as conditionally independent
>   given the cultivar's parameters would count the same shape evidence twice — squaring the
>   posterior odds it should only count once. The scale/shape split this item's own title reaches
>   for lives instead in the model's affine reparameterisation of the two *log* measurements, where
>   it costs no extra field: `log height` and `log diameter` decompose into a scale coordinate
>   (`log height + log diameter`, roughly) and a shape coordinate (`log height - log diameter`, the
>   log-ratio) without storing either combination.
> - **The field is `diameter`, not `maximumDiameter`.** UPOV TG/14's characteristic 24 explanatory
>   note reads "the maximum diameter should be observed" — "maximum" names the site the caliper
>   goes to, the fruit's widest point, the equator, not a maximum taken over repeated measurements
>   of the same fruit. The longer name reads as the latter, so the shorter one was chosen and the
>   siting is spelled out in the haddock instead.
> - **Units come from `dimensional`.** `height`, `diameter` and `weight` are `Length Double` and
>   `Mass Double` from `Numeric.Units.Dimensional`, not bare `Double`s with the unit left to a
>   comment. Consequently the log transform a model takes is on a *dimensionless* number, e.g.
>   `h /~ milli metre`, and which reference unit is chosen there shifts the resulting scale
>   coordinate's prior location — an open choice, not yet settled; see
>   [the appearance parameterisation](appearance-parameterisation.md), where it is now recorded.
> - **Height is stored, which this item did not ask for.** Both UPOV TG/14 (characteristics 23 and
>   24) and the ECPGR *Characterization and Evaluation Descriptors for Apple Genetic Resources*
>   (2022) record height and diameter as two separate readings and derive the ratio from them; the
>   observer does no arithmetic in the field, so both lengths have to be recorded, not only the one
>   this item named.
> - **Shape class (flat / round / conical) stayed out of scope**, exactly as this item's own `##
>   Done when` said: it needs discrete nodes, which `delayed-sampling` does not have. A later
>   shape-class node would be planned from the ECPGR table filed below.
>
> **The two ECPGR band tables**, quoted from ECPGR *Characterization and Evaluation Descriptors for
> Apple Genetic Resources* (2022) (also filed in full, with the UPOV TG/14 notes, in the arc's
> `research/pomological-descriptors.md`):
>
> *Table 11 — Fruit height/width mean ratio (Priority 2), adapted from Dapena et al., 2009:*
>
> | State | Ratio | Average estimated fruit shape | Example reference cultivars |
> |---|---|---|---|
> | 1 | `< 0.75` | Flat | Court-Pendu Plat (syn. Court-Pendu Rose) |
> | 2 | `0.76–0.85` | Slightly flat | Bramley's Seedling, Idared, Grenadier, Auksis |
> | 3 | `0.86–0.99` | Intermediate | Cox's Orange Pippin, Golden Noble, **Gravensteiner** |
> | 4 | `1–1.1` | Slightly elongated | Adams's Pearmain, Kidd's Orange Red, Jonagold, Treboux |
> | 5 | `> 1.1` | Elongated | Kent, Kandil Sinap, Melon (syn. Prinzenapfel) |
>
> The bands are bare ratios, with **no unit** — the standard's own way of saying the shape
> coordinate is invariant to the reference-unit choice above.
>
> *Table 14 — Fruit size (Priority 1), adapted by Szalatnay and Lateur:*
>
> | State | Fruit size | Average diameter (mm) | Average weight (g) | Example reference cultivars |
> |---|---|---|---|---|
> | 1 | Extremely small | `< 45` | `< 40` | |
> | 2 | Very small | 46–50 | 41–60 | Golden Harvey, Api Etoilé |
> | 3 | Small | 51–55 | 61–80 | Akane, Miller's Seedling |
> | 4 | Small to medium | 56–60 | 81–100 | |
> | 5 | Medium | 61–70 | 101–150 | Cox's Orange Pippin |
> | 6 | Medium to large | 71–80 | 151–200 | Holsteiner Cox |
> | 7 | Large | 81–90 | 201–250 | Mutsu, Boskoop |
> | 8 | Very large | 91–100 | 251–320 | Bramley's Seedling |
> | 9 | Extremely large | `> 100` | `> 320` | Jumbo, Howgate Wonder |
>
> Unlike Table 11, these bands **are** in millimetres and grams — the size coordinate is not
> scale-free, which is the other half of the same point.
>
> **Neither table is directly comparable to a `Fruit` record**, and the gap is concrete, not
> academic. ECPGR §2.8 states the protocol both tables rest on: *"At least 12 representative fruits
> should ideally be evaluated over a minimum of four to six years,"* and that the indicative values
> "will differ across locations and growing systems." The bands are therefore cultivar means over a
> dozen-plus fruit, while a per-`Fruit` reading in this schema is one noisy specimen of that mean —
> the averaging is the model's job, not something to read off a table. Concretely: a single fruit
> measuring 58 mm by 71 mm gives a ratio of 0.82, which lands in Table 11's state 2 ("Slightly
> flat"), while the same table lists **Gravensteiner** under state 3 ("Intermediate", 0.86–0.99). A
> single fruit's ratio must not be read straight off Table 11; only the cultivar mean over many
> fruit may be.
>
> **One finding does not belong to this item at all.** A pomological source often states a shape
> *band* — ECPGR's "Intermediate", a monograph's "hochgebaut" — without stating a height or a
> diameter at all. That is not `h/d`, because nothing was measured: it is a separate,
> independently-noisy observation of the same latent ratio, and it needs its own field and its own
> error model. That is
> [cultivar descriptions are not observations](cultivar-descriptions-are-not-observations.md)'s
> concern, not this item's, and it is recorded there now.

## Why it matters

**A minimal measurement set for `Fruit`'s `-- TODO Further properties`.** Weight, maximum
diameter, and the height/diameter ratio. All three are log-normal, all three are supported by
`delayed-sampling` today with no backlog items in the way, all three are cheap in the field (a
scale and a caliper), and for many cultivar pairs they discriminate better than colour does,
which is the most weather- and ripeness-sensitive feature on the list. Shape class (flat /
round / conical) is the natural fourth but needs discrete nodes.

## Done when

`Appearance` (or a sibling record) gains weight, maximum diameter and the height/diameter ratio
as observable fields, in place of the `-- TODO Further properties` comment. Shape class (flat /
round / conical) is out of scope here since it needs discrete nodes.
