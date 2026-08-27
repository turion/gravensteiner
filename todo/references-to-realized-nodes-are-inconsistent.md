---
status: closed
pkg: [delayed-sampling]
provenance: "Restored from history after being closed by file deletion; the deleting commit's parent, 3168fe4, holds this file's last live content, byte-identical here."
closed_by: "7dc5d7f todo: clean up completed items and align priorities"
---
# References to a realized node are handled inconsistently, and `graft` rejects them

## Why it matters

The paper's `Realize` detaches a node: its value is known, so it stops being a random variable.
`realize` implements half of that, and the half it skips makes a legitimate program fail.

`putRealized` replaces the node wholesale with `Realized a`, and `getParents (Realized _)` is
`[]`, so the realized node's own edge *to its parent* is gone. (The FIXME at the `conditionDist`
call — "Now I should sever the parent/child connection, but I can't do that because I always use
the initial dist for that" — no longer applies: `Realized` has no `initialDistribution` to
sever.)

What survives is the opposite edge. **Children keep naming the realized node as their parent:**
`marginalize` computes a realized parent's contribution with
`subst parentVar b initialDistribution` but stores the result only in `marginalDistribution`, so
the child's `initialDistribution` still says `Var v`, and `getParents` reads
`initialDistribution`.

The three functions that meet such a reference disagree about what it means:

| Function | Realized parent | Realized child |
|---|---|---|
| `marginalize` | substitutes the value — correct | — |
| `realize` | `pure ()` — correct, nothing left to condition | — |
| `graft` | `throw AlreadyRealized` | `throw AlreadyRealized` (dead, see below) |

`graft`'s behaviour is the odd one out, and it is reachable:

```haskell
a <- normalDS (Const 0) (Const 1)
_ <- value a                      -- a is now Realized
c <- normalDS (Var a) (Const 1)   -- initialize leaves marginalDistribution = Nothing,
                                  -- because getParents is non-empty
value c
```

Verified in the REPL:

```
Left (ErrorTrace {error_ = AlreadyRealized (ResolvedVariable {variable = Variable {getVariable = 0},
  node = Realized 1.4687454023458104}), trace = ["value","graft","graft"]})
```

`graft c` recursed to `graft a` and threw. Nothing about the program is unreasonable — once `a`
has a value, `c ~ N(a, 1)` is just a fresh root. Worse, whether it works depends on **non-local**
state: `normalDS (Var v) …` is fine as long as nobody has forced `v` yet, so a loop that threads
a `Variable` (as both Markov-chain tests do) breaks the moment some other part of the program
peeks at the current estimate with `value`.

The existing tests dodge it because `realize` marginalizes every child that exists *at the time
it runs*, so children created before realization are fine.

## The obvious workaround does not work

`deallocateRealized a` before creating the child fails differently:

```
Left (ErrorTrace {error_ = IndexOutOfBounds 0, trace = ["value","graft","graft"]})
```

`deallocateRealized` substitutes into the nodes that exist when it is called; the child is
created afterwards, so its `Var a` is a dangling reference. This is the second half of the
finding: **`Variable a` is a reference with no way to observe that its referent is gone.** The
API hands out `Variable`s and offers no `Value`-level accessor for a realized node's value —
`sample`/`value` return a bare `a` — so a model has no way to write "the value of `a`, whether or
not it has been realized".

## The minimal fix, verified

Changing `graft`'s realized case from a throw to `pure ()`:

```haskell
    Realized _ -> pure ()
```

makes the program above return `Right (-0.81…, -1.45…)`, and **all 17 existing tests still
pass.** It is also the consistent choice: there is nothing to graft on a node whose value is
known, `sample` already returns it (`Realized a -> return a`), and `marginalize` already handles
the realized parent by substitution. Children of a realized node need no pruning either, since
they are independent roots — the same argument that exempts realized nodes from Invariant 2.

Note this changes `value v` on an already-realized `v` from an error into a return of the value.
That is arguably better, but it is a semantic change, which is why it is recorded here rather
than slipped into the fix pass. It does not weaken the double-observation check: `observe` still
throws `AlreadyRealized`, from `lookupTerminal` rather than from `graft`.

## The deeper cleanup

The minimal fix leaves the stale edges in place. The thorough version is the module's own FIXME —
"also replace all variables in the distributions by the value" — plus the one on
`isTerminalDistribution`: "In fact, one could delete the realized node from the graph." With
substitution at realization time, children of a realized node become genuine parentless roots
with their marginal already set, and then:

- `marginalize`'s `Realized b` case, `realize`'s realized-parent case and `graft`'s case all
  become unreachable;
- the `Realized _` *child* branches in `lookupTerminal`, `graft` and `prune` are already dead
  code today — a realized node has no parents, so `lookupChildren` can never return one — and
  would stay dead by construction;
- `deallocateRealized` stops being something callers must remember, retiring the manual calls in
  both Markov-chain tests;
- dangling `Variable`s become impossible only if the node is *kept* with its value, so the
  keep-vs-delete choice needs deciding: deleting is cheaper, keeping makes stale references
  resolve instead of throwing `IndexOutOfBounds`.

Substitution is only cheap once children are reachable directly rather than by scanning every
node, so this wants [the child index](graph-has-no-child-index.md) first.

## Done when

The minimal fix lands with a regression test for the program above. Separately, realization
inlines its value and the keep-or-delete decision is recorded, at which point the manual
`deallocateRealized` calls come out of the Markov-chain tests and the dead branches come out of
`lookupTerminal`, `graft` and `prune`.
