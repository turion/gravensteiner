---
status: open
milestone: [3]
size: L
size_evidence: "that is a design question for the maintainer, not a licence to reach for the denominator"
pkg: [gravensteiner]
needs: [seed-corpus-needed]
---
# Ground colour's two axes — masking and the orange question, revisit once there is data

> **Widened.** This item covered only the chlorophyll-masking question until the arc that split
> ground colour into two independently phased axes (`green` and `yellow`) surfaced a second, related
> one: ECPGR's sixth ground-colour state, "(Yellow) - Orange", has nowhere to go now that there is no
> single green-to-orange axis for it to be a further point on. The maintainer's call, given when the
> second question was raised: *"that's the todo I meant. As part of it we'll need to research this
> topic more widely, so we do both together."* Both are revisits of the same two-axis design and share
> one research pass, so they stay one item rather than splitting into two.

## Why it matters

The model's ground colour is `GroundColour p { green, yellow :: p ClosedInterval }`: two
independently phased fields, each `Closed a = Minimal | Graded a | Maximal`. `green` is the base
skin's chlorophyll reading, `yellow` its carotenoid reading, and the two are read as separate axes
rather than positions on one green-to-orange scale. `Maximal` on `yellow` is the top of the axis —
there is nothing past it. That design raises two separate open questions about what the axes do and
do not capture.

### Question 1: chlorophyll masks carotenoid

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

### Question 2: does the carotenoid axis need to separate yellow from orange

As shipped, `yellow` has no representation for orange distinct from a fully yellow reading: an
orange base skin and a fully yellow one both record `Maximal`. Whether that is a real gap or a
correct simplification is open: does the carotenoid axis need to separate yellow from orange, or is
an orange base skin correctly recorded as maximal carotenoid — a deeper point on the same axis rather
than a different hue?

**Why the old settlement does not answer this.** The plan directory that designed the two-axis split
recorded, and then superseded, a settlement for this: *"orange records in band 6 at 0.92, past yellow
on the same axis rather than off it"* — reasoning that held only while ground colour was modelled as
a single green-to-orange axis with orange as its far end. Once ground colour became two independently
phased axes, that reasoning stopped applying: there is no longer one axis for orange to be "past
yellow" on, because "past yellow" was a position on the axis that no longer exists. The settlement is
recorded as superseded rather than deleted, and this question is what remains once it is gone.

**Why no anchor can simply be added.** ECPGR Table 16 is a **one-dimensional ordinal** descriptor —
six ordered states with cultivars, no numeric anchors and no second dimension — so it supplies no
ready-made carotenoid-vs-orange split to re-anchor onto two axes. Doing that split is domain work
nobody has done, and the standing "do not invent a reference cultivar" rule forbids supplying anchors
for either axis in the meantime. Both `green` and `yellow` already carry "no calibration anchor is
established for this axis" in `Model.hs`; this item does not change that, on either axis.

## The research task

One research pass covers both questions: how the standards and the pomological literature actually
treat green, yellow and orange in a fruit's ground colour. Specifically, find out:

- Whether any source separates carotenoid *depth* (how far chlorophyll has degraded) from carotenoid
  *hue* (whether what shows through reads yellow or orange), rather than treating "more carotenoid"
  and "more orange" as the same thing.
- Whether orange is ever recorded as its own state or its own descriptor, rather than as the top end
  of a yellow scale.
- Whether any source treats chlorophyll masking of a ground-colour reading as a recording problem
  worth flagging, or addresses it at all.

**What is already known, so it is not redone.** Two descriptors are in hand, both read from primary
documents in the plan's `research/descriptor-standards.md`:

- **ECPGR Table 16** ("Ground colour") is a one-dimensional ordinal descriptor: six ordered states —
  Yellow (Golden Delicious), Whitish yellow, Green yellow (Cox's Orange Pippin), Whitish green, Green
  (Granny Smith), (Yellow) - Orange — with cultivar examples and no published numbers. Its sixth
  state is orange, written adjacent to yellow rather than as a separate hue direction.
- **UPOV char. 29** ("Fruit: ground color") has six states — not visible, whitish yellow, yellow,
  whitish green, yellow green, green — and they are **non-monotone from state 3 onward**: state 3 is
  yellow, state 4 whitish green, state 5 yellow green, state 6 green, so no single "amount of
  yellow" or "amount of green" reading increases monotonically across states 3–6. State 1, "not
  visible", is a **not-observed marker** — the ground colour cannot be seen at all — not a value on
  any colour axis; it does not appear in UPOV's own char. 30 orange, which is *over*-colour hue, not
  ground colour.

A later session should start from those two documents (already fetched locally in the plan directory,
citations in `research/descriptor-standards.md`) and from the wider pomological literature on
chlorophyll degradation and carotenoid reveal in apple skin, since neither UPOV nor ECPGR appears to
address the *mechanism* the model cares about, only the descriptive states.

## The revisit criteria

**Question 1 (masking), falsifiable, so a later session knows what to *measure*, not just to "have
another look":** once the model is fit, ask whether the `yellow` reading's **residual variance rises
with `green`**. If the residual, once the model accounts for everything else, is flat across the
range of `green`, then chlorophyll masking is not degrading `yellow`'s quality in practice, and this
question **closes** on that finding alone — no structural change to the model is needed. If the
residual variance does rise with `green`, that is the empirical case for treating it as a real
problem, and how to address it is then a design question for the maintainer — this item states only
what would justify looking for a fix, not the shape of one.

**Question 2 (orange), a candidate criterion rather than a settled one:** once there is a corpus,
check whether any cultivar in it ends up recorded `yellow = Maximal` where an observer would have
wanted to say "orange, not merely fully yellow" — a case where the axis's ceiling is doing double
duty for two things a recorder could tell apart. That is offered as a candidate signal, not a
guarantee that the corpus will settle the question either way; if it does not arise in the corpus,
that alone does not prove the two never need separating; it means the item stays open pending either
more data or the research above.

Both criteria depend on [a seed corpus](seed-corpus-needed.md) existing and, for Question 1, a model
fit against it — that is what `needs` records, and it fits both questions rather than only the
masking one, since Question 2's criterion also needs a corpus to look for cases in.

## The trap this item warns off

`yellow = carotenoid / (1 - green)` reads as the tidy correction — normalise out how much
chlorophyll is still masking the reading — and it is the same error `e50942b` ("form: the
over-colour denominator is this project's convention, not ECPGR's") unwinds for over-colour's own
denominator: it is **bilinear in two latents**, `carotenoid` and `green`, and a
bilinear term breaks the conjugate Gaussian hierarchy the same way `overcolour / (1 - russet)` would.
A later reader revisiting this item on a positive finding for Question 1 should not reach for that
division: that is a design question for the maintainer, not a licence to reach for the denominator.

The same warning covers Question 2: the fix for an orange/yellow split is **not** a third field or a
hue-direction variable computed from `green` and `yellow` together — any such construction is the
same bilinear-in-two-latents shape and breaks conjugacy the same way. Separating carotenoid depth
from hue, if it is ever done, is a design question for the maintainer to settle, not a formula to
derive from the existing two fields.

## Done when

- This item is not acted on before [a seed corpus](seed-corpus-needed.md) exists and, for Question 1,
  a model has been fit against it — that is what `needs` records.
- **Question 1:** the revisit computes `yellow`'s residual variance as a function of `green` and
  states the result. If the residual variance does not rise with `green`, Question 1 closes,
  recording that finding as the reason: masking is not a quality problem in practice. If it does
  rise, Question 1 stays open and records that the fix is a design question for the maintainer,
  without itself reaching for `yellow = carotenoid / (1 - green)`.
- **Question 2:** the revisit checks the corpus against the candidate criterion above and records
  what it finds, without itself reaching for a third field or a hue-direction formula.
- The item as a whole closes only once both questions have a recorded disposition; either question
  may close ahead of the other, but the file stays open until both do.
