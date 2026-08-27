---
status: open
milestone: [1]
size: S
size_evidence: "A short note is appended to this file summarising the above five points, and any features or"
pkg: [gravensteiner]
kind: decision
---
# Closer study of the morphometrics paper

## Why it matters

Christodoulou et al. 2018, "Can you make morphometrics work when you know the right answer? Pick
and mix approaches for apple identification" ([PMC6188776](https://pmc.ncbi.nlm.nih.gov/articles/PMC6188776/))
is the closest prior statistical work on apple cultivar identification found during the library
survey. It uses shape-based morphometrics on leaves and fruit (PCA, LDA, random forests) and
explicitly asks whether classical statistical methods can separate cultivars — using the same
cultivar labels as ground truth that this project treats as the discrete latent to be inferred.

A closer reading could establish:

- Which features carry the most discriminating information in practice (informing which conjugate
  pairs to prioritise)
- How many cultivars they could reliably distinguish, and at what sample sizes (calibrating
  expectations for the apple model's K)
- Whether any features they use are scalar normal-normal candidates already supported today
- What observer/measurement variability they report (informing the observer accuracy model)
- Whether their dataset is public (a potential seed corpus for the evaluation harness)

## What to look for

- The feature set: which measurements on fruit vs. leaf vs. other organ
- Classification accuracy per-cultivar and overall; confusion matrix structure
- How many apples per cultivar in the training set
- Any error model or inter-observer reliability measurement
- Data availability statement

## Done when

A short note is appended to this file summarising the above five points, and any features or
dataset from the paper that transfer into the v1 schema are recorded in
[`model-v1-review.md`](model-v1-review.md) or [`apple-features-and-their-conjugate-pairs.md`](apple-features-and-their-conjugate-pairs.md).
