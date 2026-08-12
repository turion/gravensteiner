# `Value` has no affine normal form, and no way to reject non-affine expressions

## Why it matters

Affine transformation is one of the paper's two core ingredients (the other being
conjugate priors), and `Value` is where it lives. The fix pass on the port made `Sum` and
`Product` closed under the affine operations, gave them the constant-folding smart
constructors `plus` and `scale`, made `Num`/`Fractional`/`subst` total on the affine
subset, and removed the `unsafeCoerce` uses. Two things it did not fix.

### 1. Non-affine operations are still runtime errors

`Num` forces `(*)`, `abs` and `signum` to exist, and `Fractional` forces `(/)`. Only the
affine cases can be honoured:

- `val1 * val2` where neither side is a `Const` is genuinely not affine,
- `abs` and `signum` are only defined on constants,
- `val1 / val2` needs a constant divisor.

Each of those now `error`s with a message naming the expression, which is a diagnosis
rather than a fix. Making them unrepresentable means giving up the `Num` instance in
favour of explicit combinators, or indexing `Value` by whether it is constant so that
`(*)` can demand a constant operand. The trade-off is readability: `Num` is what lets a
model be written as `Var pos + Const t * Var vel`, exactly as the paper's examples spell
it.

### 2. No normal form, so conditioning matches spellings rather than structure

`Value` is an unnormalized expression tree: the same affine function has many spellings,
and `Sum` can nest arbitrarily. `marginalizeDistribution` and `conditionDist` pattern-match
on the two spellings they support — `Normal (Var v) (Const _)` and
`Normal (Product c (Var v)) (Const _)` — and throw `UnsupportedConditioning` for everything
else, including every `Sum`, i.e. every multi-parent expression. `isTerminalDistribution`
likewise recognises only fully folded constants.

Replacing the two constructors with a normalized linear combination (a map from variable
index to coefficient, plus an offset) would let those functions match on structure instead:
one clause for "affine in the parent", with the coefficient read off the map. It also makes
`getParents` exact by construction, and is a prerequisite for supernodes / multi-parent
support and for the apple model's derived observations.

## Also

`substVar` returns `Nothing` when a variable index matches but the type does not, so the
substitution is silently skipped. That situation cannot arise in a well-formed graph —
`onNode` reports it as `TypesInconsistent` — but the silence is a latent trap; it becomes
cheap to report once `Graph` tracks the type of each node.
