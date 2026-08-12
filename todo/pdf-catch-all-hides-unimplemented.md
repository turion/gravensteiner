# `pdf`'s catch-all hides unimplemented distributions

## Why it matters

`pdf` ends in

    pdf (Beta _alpha _beta) _ = throw NotImplemented
    pdf _ _                   = throw NotMarginal

That final catch-all is load-bearing in a bad way. Three consequences:

1. **It suppresses every incomplete-pattern warning in the module**, which is why the library
   compiles with zero `-Wall` warnings while a whole distribution is missing its
   implementation. `Normal2 :: Value (Double, Double) -> Distribution Double` — the beginning
   of multi-parent support via supernodes — has clauses in `subst` and `getParents` but **no**
   `pdf`, `marginalizeDistribution` or `conditionDist`. A `Normal2` node can be constructed and
   inserted into the graph; it fails only much later, when something forces a density.
2. **It conflates two unrelated errors.** `NotMarginal` means "this distribution still refers
   to variables, so it is not a marginal" — a legitimate, expected intermediate state. Reaching
   the catch-all with `Normal2` instead means "not implemented". Debugging the first while the
   second wears its name is needlessly hard.
3. It is the reason the module's other FIXMEs about a **type-level marginal/conditional
   distinction** matter: if `Distribution` were indexed by a phase tag (marginal distributions
   provably contain no `Var`), `pdf` and `sampleMarginal` would be total on the marginal index
   and `NotMarginal` would largely disappear, leaving genuine gaps to be caught by the
   exhaustiveness checker.

## Done when

The catch-all is gone: `pdf` matches every `Distribution` constructor explicitly, so adding a
constructor is a compile error until its density is supplied. Unimplemented constructors throw
`NotImplemented`, never `NotMarginal`. `Normal2` either gets its three missing operations or is
removed until supernodes are implemented — a constructor that silently corrupts a graph is
worse than its absence.
