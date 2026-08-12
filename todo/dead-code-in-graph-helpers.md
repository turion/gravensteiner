# Dead code in the graph-mutation helpers

## Why it matters

Three helpers in `Control.Monad.Bayes.DelayedSampling` have a signature and a definition and
no call sites. Dead code here is not merely untidy — it hides defects and misdirects fixes:

- **`setMarginalized`** contains a bare `error "Already realized"` (with its own FIXME:
  *"should really have a local monad with error"*). Because the function is never called, that
  `error` is **unreachable today** — so this is not "an `error` call to replace" but a decision
  to make: wire the helper in where nodes are marginalized, or delete it. `marginalize`
  currently updates the node itself.
- **`tryElse :: Error -> Maybe a -> DelayedSamplingT m a`** is unused, which is a small piece
  of luck: it is exactly the combinator needed to replace the incomplete monadic pattern binds
  in `realize` / `sample` / `observe` that currently degrade structured `Error`s into
  `Fail "Pattern match failure in do expression at …"` via the `MonadFail` instance. Fixing
  those retires the dead code rather than adding more.
- **`ensureConsistency`** — tracked separately in
  [invariants-unchecked.md](invariants-unchecked.md).

## Done when

`tryElse` is used at the pattern-bind sites; `setMarginalized` is either the single writer of
the marginalized state (with its `error` turned into a `throw AlreadyRealized`) or gone; and
no exported function is unreachable from either the public API or the tests.
