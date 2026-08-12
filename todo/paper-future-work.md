# The paper's own future work — research-grade, low priority

## Why it matters

Two items here are the paper's own stated limitations rather than gaps in this port. They are
recorded so that nobody mistakes them for oversights, and so that a future design decision can
be measured against them.

### Tractable structures beyond trees

The graph is a forest, and the paper's route past that is supernodes — see
[no supernodes for multiple parents](no-supernodes-for-multiple-parents.md). Supernodes fix
expressiveness at the junction-tree cost: the merged clique's joint is dense and its dimension
grows with what the model couples. There exist tractable structures that are *not* trees and
*not* small cliques — e.g. sparse Gaussian graphical models where the precision matrix is sparse
even though the covariance is not. Exploiting those directly, rather than by merging, is open.

Not worth attempting before supernodes exist, since supernodes are the baseline any such scheme
has to beat.

### Reordering observations, not just samples

Delayed sampling reorders *sampling*: it postpones each `sample` until a value is demanded, so
that intervening observations can be absorbed analytically first. Observations themselves are
handled in program order. The paper notes the missed opportunity: a `observe` encountered early
may block conjugacy that a later one would have permitted, and reordering the checkpoints could
absorb more of them analytically.

In this implementation the ordering is entirely the model author's: `observe` grafts, realizes,
and scores immediately. Deferring an observation means holding a pending likelihood factor
against a node and discharging it when the node's marginal is next needed — which interacts with
the weight, since `score` would then be called at a different point in the program than the
`observe` that produced it. Under SMC that changes *when* particles are reweighted and therefore
what resampling sees, so this cannot be evaluated independently of
[the SMC integration](no-smc-integration.md).

## Done when

Both are evaluated and the conclusions recorded — implementation optional. The useful deliverable
is a note saying which structures this library will and will not handle, so that a model author
knows when to stop expecting delay.
