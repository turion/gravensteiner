---
status: open
milestone: [6]
size: L
size_evidence: "Separately, a recorded decision on the opacity question, since it changes the shape of every"
pkg: [delayed-sampling]
---
# `observe` takes a `Variable`, not a `Value`

## Why it matters

`observe :: Variable a -> a -> DelayedSamplingT m ()` carries two FIXMEs of its own:

> I'd like to observe on `Value a`, but I don't know how to do that with `var1 + var2`
>
> In the paper, the observe thing has type `a -> DelayedSamplingT m a -> DelayedSamplingT m ()`,
> so one doesn't do bad things to the variable. Is this wise or is this extra flexibility ok?

They are two separate asks.

## 1. Observing an expression

A model rarely observes a latent variable directly; it observes a function of one. The paper's
checkpoint applies to an expression, and the affine machinery is there precisely so that the
observation can be pushed through it.

The multi-variable case (`var1 + var2`) does need supernodes — see
[no supernodes for multiple parents](no-supernodes-for-multiple-parents.md). But the
**single-variable affine case is tractable with what already exists**: `conditionDist` already
handles a child distribution of the shape `Normal (Product c (Var v)) (Const variance)`, which
is exactly "the observation is `c · v` plus noise". Observing `c *. var v .+. constant d` needs
only the offset folded into the observed value before conditioning. So this is a cheap and
genuinely useful increment, not something that has to wait for the hard item.

## 2. Keeping the variable opaque

Taking a `Variable` hands the caller a name they can misuse: they can `sample` the same
variable afterwards, `observe` it twice, or observe one that some other part of the program has
already realized. The errors are caught (`AlreadyRealized`), but at runtime and after the fact.
The paper's shape — the observation consumes the *computation* that produced the variable, not a
reference to it — makes the second use unrepresentable.

Whether to adopt it is a real trade-off, not an obvious win: the current flexibility is what
lets a model create a variable, observe it, and then keep referring to it, which is what the
existing Markov-chain tests do. Adopting the paper's shape means those loops are written
differently.

## Done when

`observe` accepts an affine expression in a single variable, with the offset folded in and the
multi-variable case deferred with a clear error. Test: observing `2 *. var x .+. constant 1`
against a known value gives the same posterior for `x` as observing `var y` where
`y ~ N(2x + 1, σ²)` — the two must agree analytically, which makes it a real check rather than
a smoke test.

Separately, a recorded decision on the opacity question, since it changes the shape of every
model written against the library.
