# Russet is a texture, not a colour — and the simplex premise goes with it

> **Adopted.** The v1 schema in `Gravensteiner.Model` already separates russet from `Colours` and
> drops `brown`, and the appearance parameterisation argued for here is the one chosen — see
> [the review](model-v1-review.md) and [the network design](model-v1-bayesian-network.md). What
> remains open is the naming (`Colours` still holds `yellow`/`red`/`green` rather than
> `groundColour`/`overcolour`), the pattern categorical, and the elicitation protocol, which now
> needs to reach the data-collection form and not only the type.

## Why it matters

`Colours`' fourth field is named `brown`, but the thing being described is **russet**: corky
periderm on the skin, not a pigment. That is not a naming quibble, it invalidates the model's
central assumption. Yellow, red and green partition the pigmented skin; russet *overlays* it. A
russeted patch is not "surface that is brown instead of red", it is surface whose pigment is hidden
under a different tissue — so the four numbers are not four parts of one composition, and
`Colours` is not a point on the 3-simplex at all.

The training data agrees: the one entry with `brown = 0.3` is `Observation "Boskoop"`, and Boskoop
is a heavily russeted cultivar. So the field was always doing the job of a texture.

`Main.hs` half-knew this — `Apple` carries a commented-out `-- , overcolour :: Maybe Interval`,
which is the pomological concept the model actually needs.

## The scheme pomology already uses

An apple's appearance is conventionally described by:

- **ground colour** — where on the green ↔ yellow axis the base skin sits. A *single* number in
  [0, 1], not a composition, and notably it is also the main ripening axis: chlorophyll degrades to
  reveal carotenoids, so ground colour is largely a readout of ripeness.
- **overcolour (blush) extent** — what fraction of the surface carries red. A coverage in [0, 1].
- **overcolour pattern** — blush, striped, flecked, mottled. Categorical, and strongly
  cultivar-diagnostic (Gravensteiner is striped; Jonathan is a solid blush).
- **russet extent** — coverage in [0, 1], usually concentrated around the stalk cavity.
- plus lenticels, bloom/waxiness, and so on.

## The consequence: the simplex dissolves, and so does the largest feature gap

Three scalars in [0, 1] and one categorical replace a 4-part composition. Each scalar is a
logit-normal — i.e. a **scalar** normal with a normal prior on its mean, which
`normalDS`/`observe` and `conditionDist`'s `Normal (Var v) (Const variance)` clause support
**today** — or a Beta / beta-binomial if counts are preferred.

That removes `Dirichlet` and vector-valued *carriers* from the critical path, which rev 5 called
the single largest gap. What is still wanted from
[vector-valued variables](vector-valued-variables-and-dirichlet.md) is the **multivariate normal**,
not the Dirichlet: ground colour and overcolour extent both move with ripeness, so their joint
covariance is real and a diagonal approximation throws away a genuinely informative correlation.
That is the [supernode](no-supernodes-for-multiple-parents.md) item, not the Dirichlet item — a
meaningful reprioritisation, since a multivariate normal is needed for
[the target hierarchy](apple-model-target-hierarchy.md) regardless, whereas a Dirichlet now has no
remaining client.

It also changes what the [zeros problem](apple-model-zero-colours-are-fatal.md) is. Russet extent
is 0 for most cultivars and substantial for a few — a genuinely **zero-inflated** quantity, whose
honest model is a Bernoulli "is this cultivar russeted at all" times a Beta or logit-normal extent
(beta-Bernoulli, plus a scalar chain). Overcolour extent hits 0 for real reasons too (a green
cultivar has no blush) and 1 for a fully coloured one. Ground colour, being a position rather than a
coverage, has no structural zero at all. So the presence layer that
[the reformulation options](apple-model-reformulation-options.md) recommended on numerical grounds
turns out to be required on biological ones, which is a better reason for it.

## The one thing to be careful about

Overcolour and russet are coverages of the *same* surface and can overlap, so they do not
automatically sum to anything. **How the observation is elicited decides whether the model stays
conjugate.** If a pomologist reports fractions of the whole apple, then "visible red" is roughly
blush coverage × (1 − russet coverage) — a *product of two latents*, which is bilinear, not affine,
and breaks tractability outright. If instead ground/overcolour is reported as a split of the
non-russeted skin and russet coverage separately, every quantity stays affine in one latent.

That is a rare case where a modelling constraint should be pushed into the data-collection
protocol rather than absorbed by the inference: define the fields as "russet coverage" and "blush
extent *of the non-russeted skin*", and the whole appearance model remains linear-Gaussian.

## Done when

- `Colours` is renamed (it is not a colour record — `Appearance` or similar) with fields
  `groundColour`, `overcolourExtent`, `overcolourPattern`, `russetExtent`, and `brown` is gone.
- The observation protocol above is written down next to the record, since the field definitions
  are what keep the model conjugate.
- `initialTraining` is re-encoded in the new scheme — which requires deciding what its existing
  numbers meant. Boskoop's `brown = 0.3` is russet coverage; Jonathan's `red = 0.9, yellow = 0.1`
  is a near-total blush over a yellow ground, i.e. `overcolourExtent ≈ 0.9`, `groundColour ≈ 1`,
  `russetExtent = 0` — note that this is *not* a mechanical transformation of the old numbers, so
  the training data has to be re-elicited rather than converted.
