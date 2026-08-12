# No way to build a record of variables, or to observe one partially

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
observeRec    :: (Traversable f, ...) => f (Variable a) -> f (Maybe a) -> DelayedSamplingT m ()
valueRec      :: (Traversable f, ...) => f (Variable a) -> DelayedSamplingT m (f a)
```

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

- Record-level `initialize`/`observe`/`value` exist, with `observe` accepting `Maybe` fields and
  skipping the missing ones.
- `identify` on `Apple {colours = Nothing}` returns the prior over cultivars weighted by
  `frequency`, rather than calling `error` — which requires structural change 2 in
  [the reformulation options](apple-model-reformulation-options.md).
- A test that observing a record with some fields missing gives the same posterior as observing
  only the present fields individually. That is the property the sugar has to preserve, and it is
  also a useful check on the never-grafted path, which nothing currently tests.
