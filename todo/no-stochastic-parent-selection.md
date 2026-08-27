---
status: open
milestone: [6]
size: L
size_evidence: "Two sub-requirements fall out, and they are the practical content of this requirement:"
pkg: [delayed-sampling]
needs: [discrete-nodes-and-dirichlet-categorical, exact-enumeration-of-discrete-latents, no-supernodes-for-multiple-parents]
provenance: "model-v1-delayed-sampling-requirements.md, R1 (table row and the full section 'R1 — stochastic edges, and why this is the hard one')."
---
# A node's parent cannot be selected by a discrete latent

## Why it matters

Every other requirement is about the *contents* of a node or the *number* of its parents. This one
is about **which node is the parent**, and that is a different kind of thing.

The fruit node's mean contains `mu_{z_t}`: the cultivar mean of whichever cultivar tree *t*
actually is. `z_t` is latent, so the *edge* from a cultivar node to a fruit node is itself random.
Nothing in `delayed-sampling` has a notion of this — `Value` can hold a `Var`, and `getParents`
reads the variables an expression mentions, but there is no way to write "the parent is one of
these K variables, with these probabilities". The graph is a fixed structure whose nodes carry
distributions; here the structure is part of what is being inferred.

This is the paper's spike-and-slab / stochastic-branching case (§ on programs whose control flow
depends on a random choice) generalised from two branches to K, and the paper's own treatment is to
*force* the branching variable — sample it, then proceed with a known structure. That is exactly
the right answer here, and it is the shape of the algorithm the network design calls for: force
`z_t`, and everything downstream is conjugate. So this does not require inventing a new
delayed-sampling operation; it requires that forcing a discrete variable and *then* building the
graph is expressible and cheap, and that the K alternatives can be evaluated without rebuilding
the whole graph K times.

Two sub-requirements fall out, and they are the practical content of this requirement:

1. **Evaluating K alternatives against a shared marginalized context.** Computing the posterior
   over `z_t` means evaluating the fruit likelihood under each candidate cultivar mean, against a
   Gaussian block that is identical in all K cases. Naively that is K grafts and K rebuilds; what
   is needed is to graft the shared context once and score K alternatives against it. Without this
   the per-tree posterior costs K times too much, and K is a few hundred.
2. **Retraction.** A collapsed Gibbs sweep revisits `z_t` after having conditioned on it, so the
   effect of the previous value must be removable. Delayed sampling is built around monotone
   accumulation of evidence: `realize` and `observe` move nodes forward through I → M → R and
   nothing moves back, and `observe` has additionally already applied its `score` to the weight.
   Either the sweep re-derives the Gaussian block from scratch per tree (correct, expensive) or
   there is a genuine downdate. This is the requirement most likely to be discovered late, so it is
   recorded now.

   **This requirement and
   [no supernodes for multiple parents](no-supernodes-for-multiple-parents.md) converge here, which is
   a useful coincidence.** In information form the evidence
   from one observation is an *additive* contribution to the precision and the information vector,
   `Λ += Aᵀ S⁻¹ A` and `η += Aᵀ S⁻¹ y`, so retracting it is subtraction of the same two terms —
   exact, local, and O(block size). In moment form there is no comparable downdate. So the
   representational change [no supernodes for multiple parents](no-supernodes-for-multiple-parents.md)
   needs for scale is the same one this requirement needs for correctness, and neither
   should be designed without the other.

Note that this requirement interacts with the confusion model: `sim(c, c')` is derived from the Gaussian
posterior, so the discrete block's weights depend on the continuous block's current state. The two
cannot be fitted in one pass, and the fixed-point iteration between them is part of the algorithm
rather than an implementation detail.

## Done when

- Evaluating K alternatives against a shared marginalized context is expressible and cheap: the
  shared Gaussian context is grafted once and the K candidate cultivar means are scored against
  it, rather than rebuilding the graph K times.
- Retraction exists: a collapsed Gibbs sweep can revisit `z_t` and remove the effect of its
  previous value, either by a genuine downdate or by a documented re-derivation-from-scratch
  fallback.
- Forcing `z_t` and then building the downstream graph is exercised end to end, so that the
  algorithm the network design calls for — force the discrete latent, then everything downstream
  is conjugate — is validated rather than only argued for.
