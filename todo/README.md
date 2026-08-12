# Open todos

One file per open item. Each states why it matters — citing the paper
([arXiv:1708.07787](https://arxiv.org/abs/1708.07787)) and the relevant function **by name**,
never by line number, since reformatting invalidates line numbers — and what "done" looks
like.

This folder starts with the findings from the review of the initial `delayed-sampling` port
(revision `vykonwvq`). It is **not yet the full backlog**: the systematic paper review and the
apple-model feature gaps are still to be added.

| Item | Slated for |
|---|---|
| [Graph invariants are never checked](invariants-unchecked.md) | partly rev 3, rest later |
| [`atMostOneParent` misses expression parents](at-most-one-parent-misses-expression-parents.md) | rev 3 |
| [Dead code in the graph-mutation helpers](dead-code-in-graph-helpers.md) | rev 3 |
| [`Num (Value a)` is partial *and* order-dependent](value-num-is-partial-and-order-dependent.md) | rev 3 (totality), later (affine form) |
| [`pdf`'s catch-all hides unimplemented distributions](pdf-catch-all-hides-unimplemented.md) | later |
