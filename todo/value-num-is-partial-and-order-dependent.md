# `Num (Value a)` is partial *and* silently order-dependent

## Why it matters

Affine transformation is one of the paper's two core ingredients (the other being conjugate
priors), and `Value` is where it lives. The `Num` instance implements exactly one clause per
operator and `error`s on the rest:

    Var v + value    = Sum v value
    _     + _        = error "Value.+: Not implemented"
    Const a * Var v  = Product a v
    _       * _      = error "Value.*: Not implemented"

So `Var x + Const 1` works and `Const 1 + Var x` crashes; `Const 2 * Var x` works and
`Var x * Const 2` crashes. **A `Num` instance whose `+` and `*` are not commutative is worse
than no instance at all** — it type-checks, it reads as ordinary arithmetic, and the failure is
a runtime `error` deep inside a model, not a type error at the call site. `negate`, `abs`,
`signum` and `(/)` are unconditional `error`s, and `(-)` inherits from `negate`.

`subst` has the matching hole: `subst _ _ (Sum (Variable _) _) = error "Not yet implemented"`.
Since `Sum` is the *only* thing `Var v + …` can build, any model that adds two random
variables crashes during conditioning even if the graph accepted it. This is the **second**
lock on the Kalman test's commented-out `Var posVar + Const t * Var velVar`: multi-parent graph
support alone would not be enough.

`subst` also carries the module's three `unsafeCoerce` uses (two of them in one clause, for
`Product`), guarded only by an `Int` index comparison — the FIXME asks for a type-safe
alternative, and `Typeable`/`cast` is already in scope from the existing constraints.

## Done when

**Short term (totality):** every `Num`/`Fractional` method either produces a `Value` or is a
type error, not a runtime `error`. Constant folding covers `Const`-only arguments; the mixed
cases normalize; genuinely unsupported combinations (e.g. `Var x * Var y`, which is not affine)
should be unrepresentable rather than crashing. Commutativity holds. `subst` handles `Sum`.
`unsafeCoerce` is replaced by a `cast`-based witness.

**Long term (normal form):** note that `Value` is *already* nearly an affine normal form —
`Sum` takes a `Variable` head and `Product` a constant scalar times a `Variable`. Replacing the
two constructors with a normalized linear combination (`Map Variable coefficient` plus an
offset) makes `getParents`, `subst` and constant folding total and canonical by construction,
and removes the ordering asymmetry structurally instead of by adding clauses. This is a
prerequisite for supernodes / multi-parent support and for the apple model's derived
observations.
