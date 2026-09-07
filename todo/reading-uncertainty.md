---
status: open
milestone: [3]
size: L
size_evidence: "the actual parameterisation is model-design work nobody has done"
pkg: [gravensteiner]
needs: [seed-corpus-needed]
---

# The blush reading gets noisier as russet rises, and nothing says so

## Why it matters

Question 3 of the collection form asks for blush as a fraction of the **non-russeted** skin, so
its denominator is `1 - russet`. On Egremont Russet — already the form's own reference cultivar
for ECPGR's "over 90 %" russet band, anchor 0.95 — that denominator is about 0.05: the observer is
judging blush against roughly a twentieth of the fruit's surface. Contrast Cox's Orange Pippin,
already named in the form as a "Low" russet cultivar (anchor 0.18): its denominator is 0.82,
nearly the whole surface. The same recorded overcolour fraction, whether it is 0.5 or `Maximal`,
rests on far less visible skin on the first cultivar than on the second, and nothing in the schema
or the likelihood currently says so.

**This is a modelling matter, not a form matter.** The maintainer settled the `ask` half of
challenge finding #4 — whether a live observer can reliably produce the blush reading at all on a
heavily russeted fruit, where russet overlays the very skin whose blush is being judged — with
**yes**: a pomologist can do that, question 3 does not change, and there is no russet threshold
above which the reading stops being taken. He directed the residual concern here instead: *"you can
(possibly later todo) model this uncertainty in the probabilistic model."* The reading stays in the
form because it is producible; what is missing is that the model treats a reading judged against a
twentieth of the skin as though it were as informative as one judged against all of it.

**Nothing new needs recording to fix this, when both fields are observed.** `russet :: p
ClosedInterval` on `Appearance` and `overcolour :: p ClosedInterval` on `Colouration` (`Model.hs`,
`data Closed a = Minimal | Graded a | Maximal`) mean the russet extent a precision would depend on
is already recorded for a fruit that has both readings. This is a change to how the overcolour
observation's likelihood is built, not to the schema — for those fruits.

But `russet` and `overcolour` are independently phased fields — `p` wraps each field separately, per
`Model.hs`'s own comments on the phase design, precisely so a source can state one without the
other — and `docs/collection-form.md`'s "Reading from a published description" section documents
exactly that split happening in this corpus already: a monograph can score over colour while never
mentioning russet at all, in which case russet is recorded "not observed", not "none". A
precision-depends-on-russet design therefore has an open sub-question: what precision does an
overcolour reading get when the russet extent it would depend on is itself not observed? That is a
real, already-documented case, not a hypothetical one, and this item does not answer it.

## The shape of the fix (a candidate, not a decision)

The natural direction is to give the overcolour observation's likelihood a precision that
**depends on the recorded russet extent** — more russet, less precision — so the model discounts
the reading itself rather than the observer being asked to hedge it. This is offered as a candidate
only: the actual parameterisation is model-design work nobody has done, and
[the observation model for v1](model-v1-bayesian-network.md) is where it would live.

## The trap this item warns off

Do **not** reach for `overcolour = blush / (1 - russet)`, or any other division by a latent
quantity, as the fix. That expression is bilinear in two latents, `blush` (or `overcolour` itself,
under whatever name the model gives the pre-division quantity) and `russet`, and a bilinear term
breaks the conjugate Gaussian hierarchy the same way. Three todos in this arc have already refused
exactly this shape: `turion1.1` unwound it for the over-colour denominator (the reasoning is
recorded in `Model.hs`'s own comment on `overcolour`: dividing by `1 - russet` is "bilinear in two
latents, which breaks conjugacy"), `turion1.4` refused it for chlorophyll masking, and
[the ground-colour revisit](ground-colour-masking.md) warns off the same move for the orange
question. The point of putting the uncertainty in the observation's **precision** rather than its
**mean** is exactly that it divides nothing.

## What would show this is worth acting on

Once there is [a seed corpus](seed-corpus-needed.md) and a model has been fit against it — the same
prerequisite [no-evaluation-harness](no-evaluation-harness.md) and
[ground-colour-masking](ground-colour-masking.md) record for their own revisits — check whether
heavily russeted cultivars' blush residuals are systematically larger than lightly russeted ones'.
If they are not, the extra uncertainty is not degrading the reading in practice and this item can
close on that finding alone, without any change to the model. If they are, that is the empirical
case for doing the precision work above, and exactly how to shape it is then a design question for
the maintainer — this item states only what would justify looking for a fix, not the shape of one
beyond the candidate direction named above.

## Done when

- This item is not acted on before [a seed corpus](seed-corpus-needed.md) exists and a model has
  been fit against it — that is what `needs` records.
- The revisit checks whether heavily russeted cultivars' blush residuals are systematically larger
  than lightly russeted ones', and records what it finds.
- If residuals are not systematically larger, this item closes on that finding: the extra
  uncertainty is not a quality problem in practice.
- If they are, the item records that the fix is a design question for the maintainer, without
  itself reaching for `overcolour = blush / (1 - russet)` or any other division by a latent
  quantity.
