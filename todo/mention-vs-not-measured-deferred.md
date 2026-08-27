---
status: open
milestone: [6]
size: L
size_evidence: "no cue in source file"
pkg: [delayed-sampling]
---
# `Observed` collapses `NotMentioned` and `NotMeasured` into one `NotObserved`

Low priority — revisit once a source class exists to condition the mention likelihood on.

## Why it matters

The three-way split below (drawn from the deleted requirements document) specifies three cases for
`Observed` because they cost different things in the likelihood: `NotMeasured` is free — an ungrafted variable, which is
exactly what delayed sampling already does — while `NotMentioned` is informative and should
contribute a Bernoulli on a per-source "mention indicator", conditioned on the latent value. That
needs a source class — something that knows, per literature source or per observer, how likely it
is to mention a given feature when present — which does not exist yet.

`Control.Monad.Bayes.DelayedSampling.Record`'s `observeField` therefore had two branches,
`NotMentioned` and `NotMeasured`, that did exactly the same thing (`pure ()`). A distinction that
every call site treats identically is worse than not having it: it is exactly the confusion that
prompted this file. `Observed` is collapsed to `Observed a | NotObserved` until there is a second
behaviour to distinguish.

## Shape of the fix

Reintroduce the three-way split (or a `NotObserved SourceClass` argument) once a source class with
a mention-propensity parameter exists, and give `observeField`'s absent-case branch on `NotMentioned`
the Bernoulli contribution described below. Until then, anything recorded under `NotObserved` has
thrown away the "why absent" fact — the caution about capturing this at data entry (see
[records of variables](records-of-variables-and-partial-observation.md), done — see
`Control.Monad.Bayes.DelayedSampling.Record`) still applies; it is just not enforced by the
type today.

## Done when

- A source class exists with a mention-propensity parameter.
- `Observed` regains a way to distinguish "could have been recorded but wasn't" from "the source
  cannot produce this field", and `observeField`'s `NotMentioned` case contributes the
  mention-indicator Bernoulli.
- Call sites that ingest data under today's two-way `Observed` are revisited to capture the
  distinction where the source is known, rather than losing it permanently.

## From the v1 model review (Tier 3)

**Absence of mention is not absence.** `Maybe` as the phase collapses three distinct situations into
one `Nothing`: measured, could have been recorded and was not, and could not be recorded at all (a
photograph has no weight). They have different likelihood contributions and only the first is
currently expressible. The fix is a purpose-built phase type `Observed`, designed in the section
below (drawn from the deleted requirements document) — where absence of a *feature* is
`Observed 0` rather than a missing value, because "no red on this apple" is an observation.

## From the v1 requirements document (R12)

> **Implemented as a two-way `Observed a | NotObserved` for now** in
> `Control.Monad.Bayes.DelayedSampling.Record` — the three-way split below is deferred until a source
> class exists to condition `NotMentioned`'s mention likelihood on; see
> [mention-vs-not-measured-deferred](mention-vs-not-measured-deferred.md).

`Maybe` collapses several statistically distinct situations into one `Nothing`. They need to be
distinguished at the point where the distinction is *known* — data entry — because it cannot be
recovered later. The phase parameter is the right place, since it is already generic:

```haskell
-- | Why a fruit observation has no value, recorded where it is known.
--   Observations are never vague: a fruit either gave a value or it did not.
data Observed a
  = Observed a
    -- ^ Measured. Absence of a feature is @Observed 0@, not a missing value:
    --   "no red on this apple" is an observation, and an informative one.
  | NotMentioned
    -- ^ The observer could have recorded it and did not. Weak evidence, because
    --   people record what is notable.
  | NotMeasured
    -- ^ The source could not produce it at all: a photograph has no weight, and a
    --   photograph of one side cannot give russet extent. Ignorable given the source.
  deriving (Show, Eq, Functor, Foldable, Traversable)
```

There is deliberately **no vague case**. Vagueness belongs to *cultivar descriptions*, which are
statements about a distribution rather than about a fruit, and they get their own type — see
[descriptions are not observations](cultivar-descriptions-are-not-observations.md). Uncertain fields
of a real observation (half the surface is hidden, shape depends on perspective) are `NotMeasured`
or discarded, not softened into a range.

Used as the phase, `Fruit Observed` is a real-world record and `Fruit Identity` a simulated one, so
the existing `barbies` dependency and `UUIDMap`'s indexed instances keep working unchanged.
Deliberately **no `Applicative`/`Monad`**: `<*>` would have to pick a winner between `NotMeasured`
and `NotMentioned`, and there is no defensible choice, so the ambiguity should be resolved
per-field at the call site rather than hidden in an instance.

What each case costs in the likelihood:

| Case | Contribution | Conjugate |
|---|---|---|
| `Observed x` | the density at *x* | yes |
| `Observed 0` on a zero-inflated feature | the presence indicator, a Bernoulli | yes (beta-Bernoulli) |
| `NotMeasured` | none — an ungrafted variable, which is exactly what delayed sampling does | yes, free |
| `NotMentioned` | a Bernoulli on the mention indicator, conditioned on the latent value | yes, but needs the source class |

`NotMeasured` being free is worth stating: the ignorable case is the one delayed sampling already
handles correctly by never grafting the variable, so the type is mostly making the *non*-ignorable
cases visible.
