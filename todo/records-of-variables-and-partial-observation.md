---
status: closed
pkg: [delayed-sampling, gravensteiner]
provenance: "This is the requirements document's R8 (model-v1-delayed-sampling-requirements.md), restored from history after being closed by file deletion; kept as a pointer so a later dissolution of that document does not recreate it as a duplicate."
closed_by: "7dc5d7f todo: clean up completed items and align priorities"
---
# No way to build a record of variables, or to observe one partially

> **Now has a concrete client, and a concrete shape.** The v1 schema in
> `Gravensteiner.Model` answers the `Main.hs` FIXME below directly: `Fruit`, `Collection`, `Tree` and
> `Judgement` all take a higher-kinded phase parameter, so the phase *is* the partial-observation
> mechanism. Two refinements since: the phase should be `Observed` rather than `Maybe`, so that "not
> mentioned" and "not measurable" are distinguishable (see
> [mention-vs-not-measured-deferred](mention-vs-not-measured-deferred.md)), and `Fruit.colours` is `p Colours`, which
> makes the colour fields all-or-nothing where a literature source typically gives ground colour and
> omits blush — see [nest the phase inside `Colours`](nest-phase-inside-colours.md). So the data side is settled in shape and needs
> two fixes; what this item is now about is the **`Variable` side**: mapping a record of priors to a
>
> **`Observed`'s three-way split is collapsed to two for now**, `Observed a | NotObserved` — nothing
> implements the mention likelihood that would make `NotMentioned` behave differently from
> `NotMeasured`, so the implemented type does not carry the distinction described below. See
> [mention-vs-not-measured-deferred](mention-vs-not-measured-deferred.md).
> record of `Variable`s and observing a `Fruit Observed` field by field. `UUIDMap`'s indexed instances
> are the right shape for the entity level.

## Why it matters

`Main.hs` asks for this directly: `-- FIXME HKD to define priors & observations?`. The model has
one record shape appearing in four different guises — `Colours` (observed values),
`DirichletColoursPrior` (prior hyperparameters), `DirichletColours` (sampled parameters), and
`Apple`'s `Maybe Colours` (possibly-missing observation) — which is the textbook case for
higher-kinded data: one `ColoursF f` with `f = Identity`, `f = Maybe`, `f = Variable`.

`delayed-sampling` offers no help. `newtype Variable a = Variable {getVariable :: Int}`, and every
operation takes exactly one `Variable a` and one `a`. Working with a record of four colours means
four separate `Variable Double`s threaded by hand, four `observe` calls, and no type-level
connection between the record of priors and the record of variables it produced. With the
[remaining apple features](apple-features-and-their-conjugate-pairs.md) — weight, size, shape,
patterns, ripeness, season, location, weather — that is a dozen or more variables per apple,
threaded manually.

**Partial observation is the same problem wearing a different hat.** `Apple` already has
`colours :: Maybe Colours`, and `identify` handles the `Nothing` case with
`error "not yet supported"` (its FIXME: "should just sample by frequency"). Inference-wise this
needs nothing new — a variable that is never `observe`d is simply never grafted, and delayed
sampling handles that natively; it is the reason `value` and `observe` are separate operations. What
is missing is the *API convenience*: a way to say "observe this record, whose fields are `Maybe`,
against that record of variables, skipping the `Nothing`s". Once fields multiply this stops being
convenience and becomes the difference between a maintainable model and a hand-written
combinatorial mess, since with *n* optional features there are 2ⁿ observation patterns and only one
of them can be written out by hand.

## Shape of the fix

A `Traversable`/`Representable`-based layer over the existing single-variable API:

```haskell
initializeRec :: (Traversable f, ...) => f (Distribution a) -> DelayedSamplingT m (f (Variable a))
observeRec    :: (Traversable f, ...) => f (Variable a) -> f (Observed a) -> DelayedSamplingT m ()
valueRec      :: (Traversable f, ...) => f (Variable a) -> DelayedSamplingT m (f a)
```

(`Observed` rather than `Maybe` per
[mention-vs-not-measured-deferred](mention-vs-not-measured-deferred.md) — the point of the extra
cases is that they take different paths, so a signature in `Maybe` would throw away the distinction
at exactly the boundary that needs it.)

This is pure sugar over `initialize`/`observe`/`value` and needs no changes to the graph, so it
could land immediately and independently of everything else in this backlog — which makes it the
cheapest item here by a wide margin. `barbies` or `higgledy` would give the `Maybe`-field record for
free; a hand-rolled `Representable` instance for a four-field `ColoursF` would too, with one fewer
dependency.

The interesting question is whether it should instead be the *same* shape functor as
[vector-valued variables](vector-valued-variables-and-dirichlet.md): if `Distribution` gains
`Dirichlet :: f (Value Double) -> Distribution (f Double)`, then a record of colours is a *single*
node with carrier `ColoursF Identity`, not four nodes, and `observeRec` is just `observe`. Those are
genuinely different designs — four scalar nodes with independent priors versus one vector node with
a joint prior — and the model wants the second for colours (they are constrained to sum to 1) and
the first for unrelated features like weight and size. Both layers are needed; deciding which is
which per feature belongs with the feature table.

## Done when

- Record-level `initialize`/`observe`/`value` exist, with `observe` accepting a record whose fields
  carry their observation status and skipping the absent ones.
- The skipping is driven by `Observed` rather than `Maybe` (currently a two-way `Observed a |
  NotObserved` — see the banner above); note that this still rules out a plain
  `Traversable`-with-`Maybe` signature, since
  [mention-vs-not-measured-deferred](mention-vs-not-measured-deferred.md)'s eventual three-way split
  is a design constraint the sugar has to keep accommodating even while it isn't implemented.
- Identification on a fruit with no appearance fields at all returns the regional prior `phi_g` rather
  than failing — the degenerate case, and a useful test that the never-grafted path is correct.
- A test that observing a record with some fields absent gives the same posterior as observing only
  the present fields individually. That is the property the sugar has to preserve, and it is also a
  check on the never-grafted path, which nothing currently tests.
