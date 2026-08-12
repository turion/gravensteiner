# Delayed sampling is not transparent — models must be rewritten to use it

## Why it matters

In the paper, delayed sampling is a *runtime mechanism*. The user writes an ordinary
probabilistic program — `x ~ N(0, 1)`, `observe y ~ N(x, 1)` — and the implementation
intercepts each statement, deciding on its own when to marginalize and when to sample. The
program does not mention the graph.

Here the user writes `normalDS` instead of `normal`, receives a `Variable Double` instead of a
`Double`, threads those variables through the model by hand, and calls `value` or `sample`
explicitly at the points where a real number is needed. `DelayedSamplingT` has no
`MonadDistribution` instance at all — `sampleMarginal` reaches the underlying sampler by
`lift $ normal mu (sqrt variance)`. So an existing monad-bayes model cannot be run under
`DelayedSamplingT` and get delayed sampling for free; it has to be rewritten, and the rewrite
is invasive because the *types* of all intermediate quantities change.

The module's own wish for HOAS — "It would be great if I could get some kind of HOAS going here
so I don't need to look up and rename variables all the time" — is the same complaint from the
implementer's side.

## Why it is not simply a missing instance

`MonadDistribution`'s `normal :: Double -> Double -> m Double` returns a *real number*, so any
instance for `DelayedSamplingT` would have to force a value immediately — which is precisely
what delayed sampling must avoid. Transparency therefore requires one of:

1. **Symbolic reals.** Make the model polymorphic in its numeric type, so `normal` can return
   something that is a `Value Double` under delayed sampling and a `Double` under an ordinary
   sampler. This is where a total, well-typed `Value` API pays off, and it is why
   [dropping `Num` for affine combinators](drop-num-for-affine-combinators.md) matters beyond
   tidiness: a model written against a numeric interface can only be reinterpreted if that
   interface is honest about which operations exist. Cost: every model must be written
   polymorphically, and the operations available are only the affine ones.
2. **Staged interpretation.** Interpret models in a free/operational representation and let the
   delayed-sampling interpreter decide when to force. `Variable`/`Value` is a hand-rolled
   fragment of exactly this, so the honest framing is that the package already chose route 2
   and stopped before the reification step that would hide it from the user.
3. **Accept the explicit API** and document it as the interface, treating transparency as out of
   scope. Legitimate, but it should be a recorded decision rather than the default by omission,
   because it determines whether the apple model is written twice or once.

## Done when

The choice is recorded with its consequences. If route 1 or 2 is taken: an existing monad-bayes
model runs under delayed sampling with no change to its source beyond its type signature, and a
test demonstrates that the same model text yields the same posterior under both interpretations
— with lower variance under delayed sampling.
