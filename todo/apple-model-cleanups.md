# Cleanups in `Main.hs` that are not delayed-sampling features

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
has `Exp $ log $ product [...] / beta [...]`. Every one of those round trips can overflow — `beta`
already does, for concentrations of a few hundred — and all of it is avoidable, since the natural
form is `Exp (pseudocount * logBeta')` with
`logBeta' as = sum (logGamma <$> as) - logGamma (sum as)` and, in `coloursLikelihood`,
`Exp (sum [(α_k - 1) * log x_k] - logBeta' αs)`. `Numeric.SpecFunctions` is already imported. Both
functions carry a `-- FIXME make more efficient` / `-- FIXME make more efficient with Exp & log`;
the efficiency is secondary, the overflow is the actual problem.

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

## No test suite

`gravensteiner.cabal` has an `executable` and nothing else — no `test-suite`, so nothing about the
model is checked, and `main` opens with an assertion (`if dirichletColoursNormalizable
initialSortColours then return () else error "Initial sort colours bad"`) whose own comment says
`-- FIXME this belongs to a test suite`. `-Wall` is on, which is worth keeping in mind for the dead
declarations above.

## Done when

The newtype invariants are enforced by construction rather than derived away, the debug output and
its `MonadIO`/`HasCallStack` constraints are gone, the densities stay in log space, the dead
declarations are resolved, and `gravensteiner` has a `test-suite` containing at least the
normalizability check and a finite-weights check over `initialTraining`.
