---
status: open
milestone: [3]
size: L
size_evidence: "that is a design question for the maintainer, not a licence to reach for the denominator"
pkg: [gravensteiner]
needs: [seed-corpus-needed]
---
# Chlorophyll masks carotenoid — revisit once there is data

## Why it matters

Chlorophyll masks carotenoid: while `green` reads high, the fruit's skin has not yet let carotenoid
show through, so a `yellow` reading recorded alongside a high `green` may be less an independent
observation than a **prediction of what yellow will read once green fades** — and once both are
folded into the corpus as ordinary observations, the two cannot afterwards be told apart.

`0c4cc8d` ("Model: ground colour is two variables, green and yellow") considered recording `yellow`
as not described whenever `green` reads high, precisely to keep a masked prediction out of the
corpus, and **rejected it**. The maintainer's decision is that
**both readings are always taken**, regardless of how green the fruit still reads —
`gravensteiner/docs/collection-form.md`'s question 6 carries the "always answer this question ...
never skipped on account of question 5's answer" imperative for exactly that reason. His call was to
settle the question **empirically**, once there is data, rather than by construction now: masking
may not be a real quality problem in practice, and this item is that revisit, deliberately deferred
rather than acted on today.

## The revisit criterion

Falsifiable, so a later session knows what to *measure*, not just to "have another look": once the
model is fit, ask whether the `yellow` reading's **residual variance rises with `green`**. If the
residual, once the model accounts for everything else, is flat across the range of `green`, then
chlorophyll masking is not degrading `yellow`'s quality in practice, and this item **closes** on that
finding alone — no structural change to the model is needed. If the residual variance does rise with
`green`, that is the empirical case for treating it as a real problem, and how to address it is then
a design question for the maintainer — this item states only what would justify looking for a fix,
not the shape of one.

## The trap this item warns off

`yellow = carotenoid / (1 - green)` reads as the tidy correction — normalise out how much
chlorophyll is still masking the reading — and it is the same error `e50942b` ("form: the
over-colour denominator is this project's convention, not ECPGR's") unwinds for over-colour's own
denominator: it is **bilinear in two latents**, `carotenoid` and `green`, and a
bilinear term breaks the conjugate Gaussian hierarchy the same way `overcolour / (1 - russet)` would
have. A later reader revisiting this item on a positive finding should not reach for that division;
that is a design question for the maintainer, not a licence to reach for the denominator.

## Done when

- This item is not acted on before [a seed corpus](seed-corpus-needed.md) exists and a model has
  been fit against it — that is what `needs` records.
- The revisit computes `yellow`'s residual variance as a function of `green` and states the result.
- If the residual variance does not rise with `green`, the item closes, recording that finding as
  the reason: masking is not a quality problem in practice.
- If it does rise, the item stays open and records that the fix is a design question for the
  maintainer, without itself reaching for `yellow = carotenoid / (1 - green)`.
