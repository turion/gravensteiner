# Drop `Num`/`Fractional` for hand-rolled affine combinators

## Why it matters

`Value`'s total core already exists: `Const`, `Var`, `plus` and `scale` are exactly the
affine operations, and all four are total. The only reason `Value` can still crash at
runtime is the `Num` and `Fractional` instances layered on top of them, whose signatures
force operations that are not affine to exist:

- `val1 * val2` where neither side is a `Const`,
- `abs` and `signum`, defined only on constants,
- `val1 / val2` where the divisor is not a `Const`.

Each of those `error`s with a message naming the expression. That is a diagnosis, not a
fix, and the instance is a standing lie: `Value` is not a `Num` in any lawful sense, so
any function with a `Num a =>` constraint accepts a `Value` and may blow up at runtime,
far from where the bad expression was written.

The instances buy exactly one thing: the paper's own notation, `Var pos + Const t * Var vel`.
Explicit combinators keep that nearly intact while making the partial cases unrepresentable.

## Proposed API

Drop both instances; export the affine operations under their own names, with fixities
mirroring `+` and `*`:

```haskell
var      :: (Typeable a, Eq a, Show a) => Variable a -> Value a
constant :: a -> Value a

infixl 6 .+., .-.
infixl 7 *., ./.

(.+.)   :: (Typeable a, Eq a, Show a, Num a) => Value a -> Value a -> Value a  -- plus
(.-.)   :: (Typeable a, Eq a, Show a, Num a) => Value a -> Value a -> Value a
(*.)    :: (Typeable a, Eq a, Show a, Num a) => a -> Value a -> Value a        -- scale
(./.)   :: (Typeable a, Eq a, Show a, Fractional a) => Value a -> a -> Value a
negateV :: (Typeable a, Eq a, Show a, Num a) => Value a -> Value a
```

The scaling operations take a plain `a` on the constant side rather than a `Value a`, which
is what makes them total — the same trick `scale` already uses. The Kalman expression reads
`var pos .+. t *. var vel`, and the two-parents test's `Var a + Const 2 * Var b` becomes
`var a .+. 2 *. var b`. Only `normalDS (Const 0) (Const 1)` and friends are unaffected,
since they already spell `Const` out.

### The alternative that keeps `Num`

Indexing `Value` by whether it mentions a variable:

```haskell
data Constancy = Constant | Affine
data Value (k :: Constancy) a where
  Const   :: a -> Value Constant a
  Var     :: … => Variable a -> Value Affine a
  Sum     :: … => Value k a -> Value l a -> Value (Join k l) a
  Product :: … => Value Constant a -> Value k a -> Value k a
```

This gives a *lawful* `Num (Value Constant a)` — it is just `a` — and hence numeric
literals in constant position. It does not rescue `(*)`, whose `a -> a -> a` shape cannot
express "one operand must be constant", so an explicit scaling operator is needed either
way. The index is worth having for a different reason, though: `Normal` currently takes a
`Value Double` for its *variance*, so `normalDS (Var a) (Var a)` type-checks while every
inference function (`marginalizeDistribution`, `conditionDist`, `pdf`, `sampleMarginal`)
matches `Const variance` and would throw on it. That test only passes because it calls
nothing but `ensureConsistency`. A constancy index turns that into a type error, and is the
same machinery
[the marginal/conditional distinction](no-type-level-marginal-conditional.md) wants.

## Can `Var + Var` be implemented?

`plus` accepts it today and is total, so the question is which of the resulting expressions
inference could actually support. Three distinct cases:

### The same variable twice — yes, and cheaply

`var x .+. var x` mentions one parent (`getParents` is deduplicated by `nub`), so the graph
is still a forest and `ensureConsistency` is happy. Inference nevertheless rejects it:
`marginalizeDistribution` and `conditionDist` match the spellings `Var v` and
`Product c (Var v)`, and a `Sum` of two `Var`s is neither, so it throws
`UnsupportedConditioning`. But semantically it *is* `2 *. var x`, which both functions
handle. No new theory is needed — only the normal form from
[`Value` has no affine normal form](value-affine-normal-form.md), which collapses repeated
variables into a single coefficient by construction. This is the cheapest real win here.

### Two distinct variables — yes, but only via a supernode, and for a mathematical reason

`var x .+. var y` with `x ≠ y` is what `ensureConsistency` reports as `MultipleParents`.
It is tempting to think independent parents are easy: if `x ~ N(μx, σx²)` and
`y ~ N(μy, σy²)` are independent roots, then `x + y ~ N(μx + μy, σx² + σy²)`, so
marginalization is a one-liner. Marginalization is not the problem — **conditioning is.**

Observing a child of `x + y` induces a *correlated* posterior over the pair: given
`x + y = z`, the two are no longer independent, and no pair of separate `Normal` marginals
can represent that. Keeping `x` and `y` as two nodes would therefore lose exactly the
information that delayed sampling exists to keep. So merging them into one node whose value
is the pair is not an implementation convenience; it is forced. This is the paper's
supernode construction, "much like the junction tree algorithm", and the unused
`Normal2 :: Value (Double, Double) -> Distribution Double` stub is the beginning of it —
it has no `pdf`, `marginalizeDistribution` or `conditionDist`.

Implementing it needs, in order: a multivariate-normal node; `Value` able to express an
affine map from a vector-valued variable to a scalar (a row vector against the supernode —
the linear-combination normal form again); and a merge step in `graft` that replaces two
nodes by their joint when an expression mentions both.

### More variables, and products — the same story, and a hard no

`Σᵢ cᵢ ·. var vᵢ .+. constant c₀` needs one supernode holding the joint over every distinct
variable mentioned, so the supernode's dimension grows with the expression and its
covariance is dense. That is the junction-tree clique-size blowup, inherited along with the
analogy.

`var x .*. var y` is a genuine no: the product of two normals is not normal, and there is no
conjugate update to perform. Likewise `abs (var x)`, `signum (var x)` and
`constant 1 ./. var x`. These are precisely the cases the combinator API should make
unrepresentable, so that "not affine" is a compile error rather than an `error` call.

| Expression | Affine | Tractable | Needs |
|---|---|---|---|
| `constant c`, `var x`, `c *. var x`, `var x .+. constant c` | yes | yes | works today |
| `var x .+. var x` | yes | yes | normal form only |
| `var x .+. var y`, `x ≠ y` | yes | jointly | supernode + multivariate normal |
| `Σ cᵢ *. var vᵢ .+. constant c₀` | yes | jointly | supernode, dimension = number of variables |
| `var x .*. var y`, `abs`, `signum`, division by a `Value` | no | no | keep unrepresentable |

## Done when

`Value` exports total combinators only, the `Num` and `Fractional` instances are gone, and
no function on `Value` calls `error`. Non-affine expressions are rejected by the type
checker.

Note what this deliberately does *not* cover: the forest property is a property of the whole
graph, not of one expression, so `var x .+. var y` stays a well-typed expression that
`ensureConsistency` rejects at runtime with `MultipleParents` until supernodes land. Type
safety here means "every expression you can write is affine", not "every expression you can
write is graftable".
