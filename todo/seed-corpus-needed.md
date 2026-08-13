# No seed corpus exists yet

## Why it matters

Items 6 and 7 of [the next planning session](README.md) — the scalar end-to-end harness and
[the evaluation harness](no-evaluation-harness.md) — both need real data to run against: labelled
collections and cultivar descriptions, at minimum a few hundred cultivars' worth, with a held-out
split fixed before any of it is used for fitting. No such corpus exists in this workspace today,
only the schema to hold one (`Gravensteiner.Model`, with `Observed`/`Description` wiring landed).

Building a harness against synthetic fixtures instead would validate the code but not the model —
the entire point of [the evaluation harness](no-evaluation-harness.md) is that three apples and
three cultivars cannot discriminate between competing modelling choices, and a hand-rolled fixture
set has exactly the same problem: it tests that the arithmetic is right, not that the model works.
[Closer study of the morphometrics paper](morphometrics-apple-paper.md) is the lead on where
real per-cultivar measurements might come from; this item is about the ingestion and corpus-building
work that has to happen regardless of which source is used.

## What is needed

- A decision on where the seed data comes from (monographs, pomological websites, the morphometrics
  paper's dataset, or some combination) and what licensing/attribution that implies.
- An ingestion path from that source into `Gravensteiner.Model`'s `Description`/`Collection`/
  `Judgement` records — not necessarily automated, but at least a documented manual procedure.
- A held-out split decided and recorded **before** the corpus is used for fitting, per
  [the evaluation harness](no-evaluation-harness.md)'s "done when", with reference trees (documented
  cultivar identity) reserved as ground truth.

## Done when

- A corpus of real cultivar descriptions and/or collections exists in (or is loadable into) the
  workspace, large enough to hold out a meaningful split.
- The held-out split is decided and recorded.
- Items 6 and 7 of [the next planning session](README.md) are unblocked and can proceed against it.
