# Cleanups in `Main.hs` that are not delayed-sampling features

> **Most of this file describes code that is being deleted.** `gravensteiner/app/Main.hs` is a
> precursor superseded by `Gravensteiner.Model` plus
> [the network design](model-v1-bayesian-network.md), so the `identify` faults, the debug output,
> the `beta` numerics, the dead declarations and the `Dirichlet` hyperprior all go with it rather
> than being fixed. Three findings **transfer** and are the reason to keep this file:
>
> - **The refinement newtypes do not refine anything.** `Interval` in `Gravensteiner.Model` derives
>   `Num`, `Fractional` and `Floating` exactly as before, and now has no smart constructor at all.
>   The same lesson applies unchanged, and is re-flagged in [the review](model-v1-review.md).
> - **Numerics: leave log space only at the end.** A general principle, and the new model has more
>   densities, not fewer.
> - **No test suite, and no way to tell whether the model works.** `gravensteiner.cabal` still has
>   no `test-suite`, and the evaluation gap below is *more* pressing now: the seed database will make
>   held-out identification accuracy and calibration measurable for the first time, and those are the
>   only things that can arbitrate between modelling choices made so far on statistical reasoning
>   alone.

## Why it matters

Collected in one file deliberately: none of these needs anything from `delayed-sampling`, none is a
modelling decision, and several will disappear when the model is restated as a graph — so they
should not be mixed into the feature backlog. They are, however, the reason the current code is hard
to reason about, and the refinement-type ones are the reason its invariants are not actually
enforced.

## The refinement newtypes do not refine anything

```haskell
newtype Interval    = Interval    {getInterval    :: Double} deriving (Show, Eq, Ord, Num, Fractional, Floating)
newtype Positive    = Positive    {getPositive    :: Double} deriving (Show, Eq, Ord, Num, Fractional, Floating)
newtype Nonnegative = Nonnegative {getNonnegative :: Double} deriving (Show, Eq, Ord, Num, Fractional, Floating)
```

- **`nonnegative` rejects 0.** It is `guard (i > 0)`, character-for-character the same function as
  `positive`, so the two types have identical smart constructors and `Nonnegative 0` cannot be built
  through the intended door — while `initialAppleSortPrior` sets `frequency = 0` through the *other*
  door.
- **The smart constructors are never called.** `interval`, `positive` and `nonnegative` have no call
  sites. Every value is built by numeric literal (`red = 0.9`) or arithmetic (`- log 0.2`), which
  reaches the constructor through the derived `fromRational`/`Floating`. So no invariant is checked
  anywhere at any point.
- **Deriving `Num`, `Fractional` and `Floating` destroys the invariants outright.** `Interval 0.9 +
  Interval 0.9` is `Interval 1.8`; `exp (Interval 0.5)` leaves the unit interval; `negate` leaves
  `Nonnegative`. This is the same mistake, and the same lesson, as
  [drop `Num` for affine combinators](drop-num-for-affine-combinators.md): a type whose point is a
  constraint must not derive a class whose operations do not preserve it. Expose the operations that
  *do*.
- **It answers the code's own question.** `updateDirichletColours` asks
  `-- FIXME Is the nonnegative property satisfied? Can I prove it on the type level?` — and yes:
  for *x* ∈ (0, 1], −ln *x* ≥ 0, so with `negLog :: Interval -> Nonnegative` and
  `addNonneg :: Nonnegative -> Nonnegative -> Nonnegative` the update is nonnegativity-preserving by
  construction. As written, the intermediate `Nonnegative (log $ getInterval yellow)` is a
  *negative* `Nonnegative` which is then subtracted, so the invariant is violated mid-expression and
  restored by accident. Two combinators remove the doubt and the FIXME.
- **`Colours` does not enforce the simplex.** Four independent `Interval`s, no sum-to-one constraint,
  and `noColours` (all zeros) is the base value every observation is built from — which is how the
  [zeros problem](apple-model-zero-colours-are-fatal.md) gets in. Whether to enforce it in the type
  (a smart constructor that normalizes) or to accept counts instead depends on
  [the reformulation](apple-model-reformulation-options.md); either way `noColours` should not be the
  starting point for building an observation.

## Debug output is load-bearing on the types

`dirichletColoursLikelihood` computes its denominator through four nested `traceShowWith` calls,
`sampleDirichletColours` does `liftIO $ print` per importance sample, and `identify` does
`liftIO $ print likelihoods`. The consequence is in the signatures: both
`sampleDirichletColours` and `identify` carry `MonadIO m` and `HasCallStack` **purely for the
tracing**. Removing the debug output removes both constraints, and an inference function that does
not need `IO` is a materially better building block — it can be run under `Enumerator`, under
`PopulationT`, or in a test. `quality = 10` should become a parameter rather than a `let` with
`-- let quality = 1000` commented out above it.

## Numerics: leave log space only at the end

```haskell
beta :: [Double] -> Double
beta as = exp $ sum (logGamma <$> as) - logGamma (sum as)
```

is computed in log space and then exponentiated, and both call sites immediately take the log again:
`dirichletColoursLikelihood` has `Exp $ log $ ... beta ... ** pseudocount`, and `coloursLikelihood`
has `Exp $ log $ product [...] / beta [...]`. Every one of those round trips can leave the range of
`Double`, and the failure is *underflow* rather than overflow: `ln B(α)` is large and negative for
large concentrations, so `exp` returns 0 once it drops below about −745, and the subsequent division
yields `Infinity`. In this model the trigger is the number of training observations, not the
concentrations themselves — `updateDirichletColours` grows each *v*ₖ by −ln *x*ₖ, i.e. by roughly 1
to 2 per apple, so `beta (getNonnegative <$> [yellowPrior, …])` inside
`dirichletColoursLikelihood` reaches the underflow point after a few hundred apples and
`** pseudocount` compounds it. All of it is avoidable, since the natural form is
`Exp (pseudocount * logBeta')` with `logBeta' as = sum (logGamma <$> as) - logGamma (sum as)` and,
in `coloursLikelihood`, `Exp (sum [(α_k - 1) * log x_k] - logBeta' αs)` —
`Numeric.SpecFunctions` is already imported and `Log Double` is already the return type, so nothing
ever needs to leave log space. Both functions carry a `-- FIXME make more efficient` /
`-- FIXME make more efficient with Exp & log`; the efficiency is secondary, the range is the actual
problem.

## `identify` does three separate wrong things

Recorded here for completeness; the fixes are in
[the reformulation options](apple-model-reformulation-options.md), structural changes 1–3.

- It **ignores `frequency`** — its own `-- FIXME I have to take the frequency & total number into
  account` — so a cultivar seen once competes on equal terms with one seen a thousand times.
- It **returns a sample**, `m Name`, discarding the posterior the caller wants.
- It has **no "unknown cultivar" option** — the FIXME about hallucination. Given only three trained
  cultivars it will confidently name one of them for any apple in the world.
- `identify Apple {colours = Nothing}` is `error "not yet supported"`; see
  [partial observation](records-of-variables-and-partial-observation.md).
- It has **no defined behaviour on an empty `Model`**. With `getModel` empty it reduces to
  `unweighted $ proper $ fromWeightedList $ return []`, i.e. a draw from an empty population, and
  nothing in the code or the types rules that out — `main` happens to fold `initialTraining` first.
  Either a documented non-empty precondition or a total return type (which structural change 1 gives
  for free, since an empty distribution over cultivars is representable and a sampled `Name` is not).

## Dead and duplicated declarations

- `Sorts`, `SortDescription` and `LongName` have no call sites, and `Model`'s
  `Map Name AppleSortPrior` keys by `Name` with no connection to `Sorts`'s
  `Map Name SortDescription` — two unrelated representations of "the set of known cultivars". Either
  join them or drop one. `LongName` also derives `Eq`/`Ord`/`IsString` but not `Show`, unlike `Name`.
- `gamma11pdf` is unused; it documents the Gamma(1,1) proposal density that
  `sampleDirichletColours` inlines as `Exp (sum ...)`, which would be clearer if the function were
  actually used, and unnecessary if the proposal changes.
- The commented-out `Beta`/`BetaPrior` block, kept for a per-colour beta model that the
  reformulation may or may not want.
- `DirichletColoursPrior` carries `-- FIXME naming` and `-- FIXME general dirichlet`; the
  four-hardcoded-colours shape is what
  [vector-valued variables](vector-valued-variables-and-dirichlet.md) would generalise.

## No test suite, and no way to tell whether the model works

Separate concerns that happen to share a cause. The *unit* gap first:

`gravensteiner.cabal` has an `executable` and nothing else — no `test-suite`, so nothing about the
model is checked, and `main` opens with an assertion (`if dirichletColoursNormalizable
initialSortColours then return () else error "Initial sort colours bad"`) whose own comment says
`-- FIXME this belongs to a test suite`.

`-Wall` *is* on — it lives in a `common warnings` stanza that the executable imports — but it does
not catch any of the dead declarations above, because `Main.hs` opens with `module Main where`, which
exports everything and so silences `-Wunused-top-binds`. Changing it to `module Main (main) where`
turns the whole dead-code list into compiler warnings, which is a better way to keep it from growing
than this file is.

The *evaluation* gap is the more serious one, and it is not a test-suite question. There is no
measurement of whether the model identifies apples correctly: no held-out split, no accuracy figure,
no calibration check on the probability it will eventually report. With three apples and three
cultivars, one apple each, no modelling error is detectable — every candidate reformulation in
[the options](apple-model-reformulation-options.md) fits this data perfectly, so the training set
cannot discriminate between them. That matters for sequencing: the reformulation decision is being
made on statistical reasoning alone, and it should be *re*-checked against an evaluation harness as
soon as there is enough data to hold any out. Calibration deserves naming separately from accuracy,
because the stated goal is to report a *probability* that the identification is right (the
hallucination FIXME), and a model can rank cultivars well while being badly overconfident — which is
the expected failure mode here, given that a per-cultivar posterior fitted to one apple has almost no
spread.

## Done when

The newtype invariants are enforced by construction rather than derived away, the debug output and
its `MonadIO`/`HasCallStack` constraints are gone, the densities stay in log space, the dead
declarations are resolved, `Main.hs` exports only `main`, and `gravensteiner` has a `test-suite`
containing at least the normalizability check and a finite-weights check over `initialTraining` —
plus, once there is data to spare, a held-out identification accuracy and a calibration check.
