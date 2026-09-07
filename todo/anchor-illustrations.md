---
status: open
milestone: [2]
size: L
size_evidence: "Real, bounded curation work, not a research gap"
pkg: [gravensteiner]
---
# Open-licensed photographs to illustrate the form's anchors

## Why it matters

The maintainer asked, after reading the form: "do they have pictures with open licenses that would
illustrate the anchors? If yes, they need to be linked (and vendored in our repo) in the form. If
no, are there reliable open licence pictures that we could use?" His decided
route: **hand-curated open-licensed photographs for `gravensteiner/docs/collection-form.md`'s
anchors, compared against the ECPGR/FRUCTUS reference figures — by image recognition and by him as
a human — rather than vendoring the reference figures themselves.** This item records the research
already done, so a later session does not redo it.

### Nothing open illustrates the scale that most needs it

The over-colour coverage slider (ECPGR Table 17) has **no referenced figure anywhere in either
standard** — not in the 2022 ECPGR descriptor list, not in UPOV TG/14/10. It is the one scale a
picture would help the most, and it is the one neither publishes.

### Correction to this round's own findings: UPOV illustrates no russet percentage

An earlier pass of this same research said "`Ad. 35`/`36`/`37` illustrate russet by zone." That is
wrong, on closer reading of TG/14/10. `Ad. 35`/`36`/`37` are one or two sentences of **pure text**
each, pointing at `Ad. 40` — and `Ad. 40` is a *shape* diagram, knife lines (`a-b`, `e-f`) marking
where to cut the fruit, not a picture of any given russet coverage. **UPOV carries no picture of
what a given russet percentage looks like, anywhere in TG/14/10.**

### The UPOV lead

`https://www.upov.int/en/web/upov/terms-of-use` grants CC BY 4.0 to UPOV's own online publications
— "UPOV online publications and other online content are issued under an Attribution 4.0
International CC license (CC BY 4.0)" — "[e]xcept ... third party content". Searching
`pdftotext -layout` of TG/14/10 for `copyright|creative commons|CC BY|all rights|©`
(case-insensitive) returns **zero matches** anywhere in the document, including on the `Ad. 33`
six-panel pattern diagram (the six `OvercolourPattern` states). That absence of a credit line is
suggestive that the diagram is UPOV's own commissioned artwork and so plausibly covered by the CC
BY 4.0 grant — but **not conclusive**, and it is not being vendored on this evidence alone.
Recorded as the one plausible open route: `upov.mail@upov.int` is UPOV's general contact, though no
page promises apple-diagram permissions specifically.

### The FRUCTUS lead

Every one of ECPGR's own apple figures carries a named credit — `Figure 6`/`7`/`8`/`9`/`18` and
`Figure 3` all say "(Szalatnay, 2006)". That traces to David Szalatnay's *Obst-Deskriptoren NAP —
Descripteurs de fruits PAN* (FRUCTUS/Agroscope, new edition 2021),
<https://www.fructus.ch/wp-content/uploads/deskriptoren-handbuch_nap_2021.pdf>, whose impressum
reads "© 2006 Alle Rechte vorbehalten" (all rights reserved) — **not open-licensed**. It is
nonetheless the **only** source found that pictures all four scales the form needs, coverage
included: an illustrated 1/3/5/7/9-point ground-colour scale, an illustrated 1/3/5/7/9-point
over-colour-coverage scale (the one ECPGR Table 17 and UPOV char. 32 leave unillustrated
everywhere else), the over-colour-hue scale ECPGR's own Figure 7 is drawn from, and russet
illustrated separately by zone (eye basin, cheeks, stalk cavity), each with its own illustrated
coverage scale. Contact: FRUCTUS, Müller-Thurgau-Strasse 29, 8820 Wädenswil, `info@fructus.ch`,
+41 44 518 03 40.

### Why hand-curation, not the reference figures, is the route

The maintainer's ask is for open-licensed *photographs* to compare against the reference figures,
not for the reference figures themselves — those stay all-rights-reserved absent a reply from
FRUCTUS or a firmer confirmation from UPOV. Wikimedia Commons (per-image free licences; individual
files CC BY-SA, CC0 or PD, per Commons:Licensing policy) and the USDA Pomological Watercolor
Collection (confirmed public domain, Public Domain Mark 1.0, 3,807 apple watercolours) both hold
real open-licensed apple imagery, including named russet cultivars (Roxbury Russet, Golden Russet
and Egremont Russet all confirmed present in both). **The catch:** both are organised **by
cultivar name only** — no subcategory on Commons or in the USDA collection groups images by
pattern, russet extent or ground colour, so neither can be searched *for* "35 % coverage" the way
the FRUCTUS handbook is laid out. Using either means hand-picking a specific photo of a specific
named cultivar already known to sit at a given point on a scale — exactly the anchor-cultivar
approach the form already uses in words (Gravensteiner/striped, Jonathan/solid blush,
Boskoop/~50 % russet, Egremont Russet/>90 %) — and then checking that one photo's individual
licence. Real, bounded curation work, not a research gap, but not "link a page" the way a single
illustrated-scale PDF would have been.

## Done when

- For each anchor `gravensteiner/docs/collection-form.md` names, an open-licensed photograph is
  found (Wikimedia Commons or the USDA Pomological Watercolor Collection, per-item licence
  confirmed) and compared against the ECPGR/FRUCTUS reference figure for that scale, both by image
  recognition and by the maintainer as a human.
- The photograph, once accepted, is vendored into the repo and linked from the form, with its
  licence recorded next to it.
- Every anchor traces to `research/descriptor-standards.md`, per the standing "do not invent a
  reference cultivar" rule — this item finds pictures for anchors the form already names, it does
  not invent new ones.
- If FRUCTUS or UPOV grants reuse in the meantime for the scale it covers, that supersedes
  hand-curation for that scale rather than being pursued alongside it.
