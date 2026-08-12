# Open todos

One file per open item. Each states why it matters — citing the paper
([arXiv:1708.07787](https://arxiv.org/abs/1708.07787)) and the relevant function **by name**,
never by line number, since reformatting invalidates line numbers — and what "done" looks
like.

This folder started with the findings from the review of the initial `delayed-sampling` port.
The fix pass that followed closed most of them: the graph invariants are now checked by
`ensureConsistency` and exercised by the test suite, the forest predicate is derived from
`getParents` instead of matching two distribution shapes, the dead graph helpers are wired
in, and `Value`'s arithmetic and substitution are total and free of `unsafeCoerce`. What is
left of those findings is below, in the first two files.

It is **not yet the full backlog**: the systematic paper review and the apple-model feature
gaps are still to be added.

| Item | Slated for |
|---|---|
| [`graft` and `prune` scan for all marginalized children](graft-does-not-use-invariant-2.md) | with the child index |
| [`Value` has no affine normal form](value-affine-normal-form.md) | before multi-parent support |
| [`pdf`'s catch-all hides unimplemented distributions](pdf-catch-all-hides-unimplemented.md) | later |
