# Open todos

One file per open item. Each states why it matters — citing the paper
([arXiv:1708.07787](https://arxiv.org/abs/1708.07787)) and the relevant function **by name**,
never by line number, since reformatting invalidates line numbers — and what "done" looks
like.

Two sources so far. The **port review** and the fix pass that followed it: that pass closed
most of its own findings (the graph invariants are now checked by `ensureConsistency` and
exercised by the test suite, the forest predicate is derived from `getParents` instead of
matching two distribution shapes, the dead graph helpers are wired in, and `Value`'s arithmetic
and substitution are total and free of `unsafeCoerce`), leaving the remainders below. The
**paper review** contributes the rest: the port implements the paper's operations
(`Initialize`, `Marginalize`, `Sample`, `Observe`, `Realize`, `Graft`, `Prune`) and its three
node states faithfully enough that the structural gaps are elsewhere — in what the graph can
represent, what the types can rule out, and what the package is ever run inside.

Still to be added: the feature gaps that specifically block porting the apple cultivar model.

## Correctness

| Item | Slated for |
|---|---|
| [References to a realized node are handled inconsistently](references-to-realized-nodes-are-inconsistent.md) | next — has a reachable failing program |

## Representation and types

| Item | Slated for |
|---|---|
| [Drop `Num` for affine combinators](drop-num-for-affine-combinators.md) | soon — mechanical |
| [`Value` has no affine normal form](value-affine-normal-form.md) | before multi-parent support |
| [No supernodes, so a node cannot have two parents](no-supernodes-for-multiple-parents.md) | blocks the apple model |
| [Marginal and conditional distributions are not distinguished in the type](no-type-level-marginal-conditional.md) | with the normal form |
| [`pdf`'s catch-all hides unimplemented distributions](pdf-catch-all-hides-unimplemented.md) | later |

## Performance

| Item | Slated for |
|---|---|
| [`Graph` has no child index, so every operation scans every node](graph-has-no-child-index.md) | next — prerequisite for several others |
| [`graft` and `prune` scan for all marginalized children](graft-does-not-use-invariant-2.md) | with the child index |

## Coverage

| Item | Slated for |
|---|---|
| [Only `Normal` is usable, and only normal-normal delays](conjugate-pairs-beyond-normal.md) | beta and gamma are confirmed needs; the rest per pair |
| [`observe` takes a `Variable`, not a `Value`](observe-takes-a-variable-not-a-value.md) | single-variable case is cheap now |
| [The paper's examples are only partly covered by tests](missing-paper-examples-as-tests.md) | alongside each fix |

## Integration

| Item | Slated for |
|---|---|
| [No SMC integration — the paper's whole payoff is unrealised](no-smc-integration.md) | the point of the package |
| [Delayed sampling is not transparent to monad-bayes models](not-transparent-to-monad-bayes-models.md) | needs a decision, not code |
| [The paper's own future work](paper-future-work.md) | research-grade |
