# Open todos

One file per open item. Each states why it matters — citing the paper
([arXiv:1708.07787](https://arxiv.org/abs/1708.07787)) and the relevant function **by name**,
never by line number, since reformatting invalidates line numbers — and what "done" looks
like.

Three sources. The **port review** and the fix pass that followed it: that pass closed
most of its own findings (the graph invariants are now checked by `ensureConsistency` and
exercised by the test suite, the forest predicate is derived from `getParents` instead of
matching two distribution shapes, the dead graph helpers are wired in, and `Value`'s arithmetic
and substitution are total and free of `unsafeCoerce`), leaving the remainders below. The
**paper review** contributes the rest: the port implements the paper's operations
(`Initialize`, `Marginalize`, `Sample`, `Observe`, `Realize`, `Graft`, `Prune`) and its three
node states faithfully enough that the structural gaps are elsewhere — in what the graph can
represent, what the types can rule out, and what the package is ever run inside. The **apple model
study** contributes the last group: what `gravensteiner/app/Main.hs` needs before it can be ported,
plus the model's own open questions.

Two things came out of that study that are worth reading before picking anything up.

The apple model currently does its conjugate update **by hand** —
`updateDirichletColours`/`updateModel` are the update, and no inference monad appears outside
`identify`. So porting it is a rewrite, not a wrapping, and the model should change while it is
being rewritten; the likelihood is chosen for hand-derivability rather than for fitting apples, and
it has a fatal defect at zero. Hence
[the reformulation options](apple-model-reformulation-options.md), which is a decision to make
before any port begins, because the two serious candidates need *different* features from
`delayed-sampling`.

Conversely, the port is less blocked than the feature list suggests. Weight, size and shape ratios
are scalar normal-normal chains that work **today**, a finite discrete latent can be enumerated
outside the graph with no new features, and the graph, transformer and all seven public operations
are already polymorphic in the carrier type — the scalar-only assumption lives in the
`Distribution` GADT and its five interpreters, and nowhere else.

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

## The apple model — what it needs from `delayed-sampling`

| Item | Slated for |
|---|---|
| [`Distribution` is scalar-only, so there is no `Dirichlet` node](vector-valued-variables-and-dirichlet.md) | the single largest gap |
| [Nothing discrete exists, so the cultivar cannot be a node](discrete-nodes-and-dirichlet-categorical.md) | with the vectors — a categorical's parameter is a vector |
| [A finite discrete latent should be enumerated, not sampled](exact-enumeration-of-discrete-latents.md) | route (1) needs nothing new — do that first |
| [No record of variables, and no partial observation](records-of-variables-and-partial-observation.md) | cheapest item here; pure sugar over the existing API |
| [A trained model cannot be saved or reloaded](marginals-cannot-be-saved-or-reloaded.md) | the pieces exist; needs a name and a round-trip test |
| [Training must not grow the graph](streaming-training-with-bounded-memory.md) | follows from the realized-node fix + child index |

## The apple model — its own open questions

| Item | Slated for |
|---|---|
| [The likelihood is not settled — three reformulations](apple-model-reformulation-options.md) | **decide before porting** |
| [Exact zeros in the colour proportions are fatal](apple-model-zero-colours-are-fatal.md) | now — this is why the executable crashes |
| [The planned features, and which are absorbable](apple-features-and-their-conjugate-pairs.md) | three of them work today |
| [Cleanups that are not delayed-sampling features](apple-model-cleanups.md) | independent of everything else |
