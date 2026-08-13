# Cultivar descriptions are not fruit observations

## Why it matters

The corpus will be built from two kinds of datum and they are not the same kind of thing:

- **(a) Fruit observations.** A photo on Wikipedia, a pomologist with an apple in hand. These give
  **point values**. Some are unrecoverable — one sees half the surface, shape depends on
  perspective — and for now those fields are simply discarded rather than modelled.
- **(b) Cultivar descriptions.** "Gravensteiner has short stems, waxy skin and red stripes", in a
  monograph or from a pomologist speaking generally. These are **statements about a distribution**,
  not about any fruit. Nobody weighed anything.

An earlier version of [the requirements](model-v1-delayed-sampling-requirements.md) got this wrong
by treating "medium-large" as an *interval-censored observation of one fruit*. It is not a censored
observation, because it is not an observation: no single fruit is being described. That framing also
made the likelihood non-conjugate (a difference of normal CDFs) and so invented a requirement that
does not exist. Separating the two kinds removes it.

## What a description actually asserts

Both readings of "medium-large" are legitimate, and they are claims about **different parameters**:

- *The point between medium and large.* A claim about **location** — about `mu_c`.
- *Fruit of this cultivar mostly fall between medium and large.* A claim about **spread** — about the
  variance components.

So the crisp statement, and the correction to the interval idea:

> **Vagueness is a weak pseudo-count on the location. A stated range is a claim about the spread.**
> They are different parameters, and an interval conflates them.

That also disambiguates the vocabulary usefully: "medium-large" (a hyphenated compound, one point)
is a location claim, whereas "medium to large" (a range) additionally claims spread. The corpus
should preserve which was written.

## The representation: elicit to the conjugate family

Rather than an interval, elicit each described feature into a **pseudo-dataset** on that feature's
transformed scale — the scale from [the network design](model-v1-bayesian-network.md), so log weight
and logit coverage:

```haskell
-- | A statement about a cultivar's distribution, elicited from a description.
--   Contrast 'Observed', which is about one fruit and is never vague.
data Described a
  = DescribedAs (Elicited a)
  | NotDescribed
    -- ^ The source could have described this feature and did not. Weak evidence,
    --   because authors mention what is notable.
  deriving (Show, Eq, Functor, Foldable, Traversable)

data Elicited a = Elicited
  { location :: a
    -- ^ Where the centre of the cultivar's distribution is claimed to be.
  , strength :: Double
    -- ^ How much this claim is worth, in units of "equivalent fruit observed".
    --   A confident monograph is worth more than an offhand remark; this is where
    --   vagueness lives.
  , spread :: Maybe (Spread a)
    -- ^ Only when the text claims variability ("very uniform", "medium to large").
  }
  deriving (Show, Eq)

data Spread a = Spread { scale :: a, scaleStrength :: Double }
  deriving (Show, Eq)
```

The point of these shapes is that they are exactly the sufficient statistics of a normal-inverse-gamma
update. `location` and `strength` are the *m* and *κ* of the conjugate prior on a Gaussian mean;
`spread` supplies the *s²* and *ν* on its variance. So a description enters the model through the
**same conjugate machinery as an observation**, with an effective count instead of a count of one,
and needs nothing new:

- Location only → an ordinary normal-normal contribution to `mu_c`. Already supported.
- With spread → inverse-gamma on the variance, which is R7's `Gamma` and nothing more.
- Several descriptions of one cultivar → pseudo-counts accumulate, exactly as datasets do. *N*
  monographs combine the way *N* apples would.

**This removes a requirement rather than adding one.** The interval-censoring item (R14) can be
dropped: observations are never vague, and descriptions are vague in a way the conjugate family
already expresses.

### Pseudo-observations, not a hand-set prior

Mathematically a pseudo-observation and a prior contribution are the same thing for conjugate
Gaussians, so "reified cultivar prior" is an accurate name for what this is. But it should be
*implemented* as an accumulation of identified likelihood terms rather than as a prior computed once,
for three practical reasons: descriptions arrive continuously as the corpus grows; a description can
turn out to be wrong, or to be a duplicate, and has to be removable; and "which sources drove this
conclusion" must be answerable, which needs the contribution to stay attributable to a record. The
removability requirement is the same downdate that R1 needs for Gibbs retraction.

## The schema addition

A description is a third top-level entity alongside collections and judgements — it references a
cultivar, not a tree, and has no collection, no date of harvest and no ripeness:

```haskell
data Description p = Description
  { cultivar :: UUID
  , author :: UUID              -- ^ 'Person'; carries the same bias term as an observer
  , source :: Source            -- ^ monograph / website / personal communication
  , stated :: Appearance Described
  , published :: p Day
  , cites :: [UUID]             -- ^ known derivation from earlier descriptions; see below
  , uuid :: UUID
  }
```

with `Observations` gaining `descriptions :: UUIDMap (Description Maybe)`. Note the two phases doing
different jobs: `p` marks record-level fields that may be unknown (a website with no date), while
`Described` marks per-feature claims that may be absent. `Fruit` uses `Observed` in the same
position, and the two never mix — which is the point of making them separate types.

In the network this attaches directly to the cultivar level, bypassing tree, year, collection and
ripeness entirely:

```
  elicited claim about feature f  --->  mu_c  (+ author bias b_o, + source bias e_s)
```

## Three hazards specific to literature

**Books copy each other, so descriptions are not independent.** Pomological literature is heavily
derivative — later monographs crib from earlier ones, sometimes verbatim, sometimes through several
generations. Ten descriptions of a rare cultivar may be one description restated ten times. If
pseudo-counts simply add, the model becomes confidently wrong in a way that is very hard to detect
afterwards, and it will be worst exactly where data is thinnest and the prior matters most. Hence
`cites`, and failing that a cap on total elicited strength per cultivar per lineage. **This is the
single biggest risk in seeding from literature** and it should be designed for before ingestion, not
discovered later.

**Books describe show fruit.** A monograph describes a well-grown, characteristic specimen, not the
average of what a tree bears. That is a systematic offset in size and colour, and it is the same
phenomenon as the collection selection protocol in [the review](model-v1-review.md) — so it belongs
in the source-class bias `e_s` rather than being absorbed into `mu_c`.

**A described spread is the *total* observable spread.** A book describing what one typically sees is
describing the marginal over trees, years and ripeness, i.e. `S_tree + S_ty + S_within` together, not
`S_within` alone. So an elicited spread constrains the sum and **cannot be attributed to one
component**; only field data with several fruit per tree and several trees per cultivar decomposes it.
Attributing a book's spread to `S_within` would understate tree and year variation and make the model
overconfident about new trees.

## The vocabulary is part of the corpus

"Medium-large" has to become a number on the log-weight scale, and that mapping is **data, not a
constant in the reader**: it differs by author, by era and by region, it is itself uncertain, and it
must be recorded and revisable. Two consequences. The mapping should live in the database next to the
descriptions that use it, versioned like everything else. And the residual disagreement between
authors' vocabularies is precisely what the author and source bias terms absorb — which is another
reason those are not optional extras.

## Done when

- `Observed` and `Described` exist as distinct types, with `Fruit` using the former and `Description`
  the latter, and no `Coarse`-style case in `Observed`.
- The elicitation of a description into `(location, strength, spread)` is specified per feature, with
  the adjective vocabulary recorded as data.
- The lineage question has a decision: either `cites` is populated during ingestion, or the strength
  cap is applied and documented. Not left to default.
- A description contributes through the same conjugate update as an observation, is attributable to
  its `Description` record, and is removable.
- R14 is struck from [the requirements](model-v1-delayed-sampling-requirements.md).
