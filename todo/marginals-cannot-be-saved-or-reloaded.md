---
status: open
milestone: [6]
size: L
size_evidence: "A decision on the persistence format, recorded."
pkg: [delayed-sampling, gravensteiner]
---
# A trained model cannot be extracted from the graph or loaded back into one

> **The target shape is not a `Map`.** This file is written around extracting one marginal per
> entity and reloading it with `initialize`. Under the crossed hierarchy in
> [the network design](model-v1-bayesian-network.md) that is lossy in the way that matters: the
> cultivar means are *correlated* in the posterior — they share a grand mean, a pedigree prior, and
> every observer and year effect — so per-entity marginals discard exactly the couplings that let
> one cultivar's data inform another's. Persistence is a **sparse precision matrix over all entity
> latents** plus the Dirichlet, calibration and Beta parameters. The `marginal` operation and the
> round-trip test below are still the right first step and still needed; they are just not the whole
> feature. See the full case below, drawn from the deleted requirements document.

## Why it matters

The apple model is meant to be *trained once and used many times*: `Model = Map Name AppleSortPrior`
is a serialisable summary of everything learned, `updateModel` folds observations into it, and
`identify` reads it. That works today only because the conjugate update is done by hand in pure
Haskell. Port it to delayed sampling and the learned state moves *into* the graph, where

```haskell
newtype Variable a = Variable {getVariable :: Int}

data Graph = Graph { nodes :: IntMap SomeNode, maxKey :: Int }
```

a `Variable` is an index into a per-run `IntMap` and means nothing outside the
`DelayedSamplingT` computation that created it. Training in one process and identifying in another
therefore needs a way out of the graph and back in.

## What already exists, and what is actually missing

Less is missing than it looks, but it is undocumented and not obviously safe. The module has **no
export list** (`module Control.Monad.Bayes.DelayedSampling where`), so all of this is already
public:

- `lookupVar :: Variable a -> DelayedSamplingT m (Node a)` and
  `currentDistribution :: Node a -> Maybe (Distribution a)` together read a node's distribution.
- `initialize :: Distribution a -> DelayedSamplingT m (Variable a)` puts a distribution back in.

So `graft var >> (currentDistribution <$> lookupVar var)` is the extraction recipe and `initialize`
is the loader. Three things stand between that and a usable feature:

1. **The `graft` is not optional, and which nodes it matters for is subtle.**
   `currentDistribution` returns `fromMaybe initialDistribution marginalDistribution`, and
   `marginalDistribution` is populated in two places: by `initialize`, but *only* when
   `null $ getParents initialDistribution`, and thereafter by `marginalize`/`setMarginalized`. So the
   behaviour splits. For a **root**, the stored marginal is already the posterior given everything
   observed so far, because `observe` conditions the parent through `conditionDist` as it goes —
   reading it without grafting is correct. For a node **with parents** that has never been grafted,
   `currentDistribution` silently returns `initialDistribution`, i.e. the prior, still mentioning
   `Var`s. Same shape of value, no signal, and the mistake is invisible in exactly the case where a
   caller is most likely to make it. A `marginal :: Variable a -> DelayedSamplingT m (Distribution a)`
   that grafts first and is named for what it returns is the fix, and it is a handful of lines.
2. **The result may not be self-contained.** A `Distribution` can reference variables (`Var`), and
   such a value is meaningless in another graph. Extraction must either require a
   variable-free distribution or fail with an `Error` — which is exactly the marginal/conditional
   distinction that [no type-level marginal/conditional](no-type-level-marginal-conditional.md)
   proposes to make a type-level property. If that lands, "extractable" and "marginal" become the
   same predicate and this item gets its correctness guarantee for free.
3. **There is no serialisation.** `Distribution` derives `Show` and `Eq` and nothing else — no
   `Read`, no `ToJSON`, no `Binary`. `Show` output is not a persistence format, and `debugGraph`
   /`debugGraphIO` are debug aids (the latter just `print`s every node). Whether persistence should
   be `Distribution`'s problem or the model's — i.e. write out `Map Name AppleSortPrior` derived
   *from* the marginals, keeping the file format independent of the library's internals — is worth
   deciding rather than defaulting.

## Done when

- `marginal :: Variable a -> DelayedSamplingT m (Distribution a)` exists, grafts, and rejects (or
  makes impossible) a distribution that still references variables.
- A round-trip test: build a graph, observe, extract the marginals, start a fresh graph with
  `initialize` from them, observe more, and check the posterior equals the one from doing all the
  observations in a single graph. That equality is the whole point of a conjugate model, and nothing
  currently tests it — it is also a sharp test of the conjugate updates themselves, sharper than the
  existing statistical acceptance tests, since it compares two exact computations rather than a
  sample against a tolerance.
- A decision on the persistence format, recorded.

## From the v1 requirements document (R9)

[Marginals cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md) is written
around extracting a per-entity marginal and reloading it with `initialize`. Under a crossed design
that is **lossy in a way that matters**: the posterior over cultivar means is correlated — because
they share `mu_0`, a pedigree GMRF, and every observer and year effect — and storing per-cultivar
marginals discards precisely the correlations that let one cultivar's data inform another's. So
persistence is a sparse precision matrix over the entity latents plus the Dirichlet, calibration
and Beta parameters, and the round-trip test in that file becomes: reload, observe more, and check
the result equals a single-session fit. That equality is a sharp test of the whole conjugate
apparatus and nothing currently tests it.

## From the v1 requirements document (R15)

| # | Requirement | Needed for | Status |
|---|---|---|---|
| R15 | A moment-form serving cache extracted from the information-form fit | answering queries without refitting | **new** |
