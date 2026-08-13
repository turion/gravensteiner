# Haskell Bayesian statistics library landscape

## Why it matters

Before investing in new infrastructure it is worth knowing what already exists,
so this project does not duplicate solved problems and can borrow from working art.
This note records the state of the Hackage ecosystem as of 2026-08-13.

## Libraries surveyed

### `monad-bayes` — already in use

General probabilistic programming via probability monads. Provides `MonadDistribution`,
`MonadMeasure`, and a suite of inference transformers: SMC, RMSMC, PMMH, Metropolis-Hastings,
Enumerator. It is already a dependency and one of the project's maintainers (`turion`) is on the
package. The inference machinery is fully general but operates by forward simulation; no analytic
marginalization or conjugate shortcutting is built in. Everything `delayed-sampling` adds is
novel relative to it.

### `delayed-sampling` — this repository; novel Haskell infrastructure

The only Haskell port of Murray et al. "Delayed Sampling and Automatic Rao-Blackwellization of
Probabilistic Programs" (AISTATS 2018, [arXiv:1708.07787](https://arxiv.org/abs/1708.07787)). The
original authors implemented the approach in **Anglican** and a new PPL called **Birch**. Nothing
equivalent appears on Hackage. The full R1–R15 requirements backlog is what it needs to run the
apple model.

### `hakaru` — research EDSL, unmaintained

Indiana University group, last Hackage release 2015. Performs symbolic disintegration and
simplification of probabilistic programs, which handles some conjugate structure. Not a practical
dependency: no recent releases, targets GHC ≤ 8.x, and its approach is symbolic rewriting rather
than the graph-based dynamic marginalization that delayed sampling uses.

### `bayes-stack` — Gibbs sampler, unmaintained

Gamari (2012). Provides `BayesStack.DirMulti` (Dirichlet-Multinomial conjugate) and a
`BayesStack.Dirichlet` module. Closest in spirit to what `Main.hs` hand-rolled, but restricted to
Gibbs sweeps, no analytic graph, and unmaintained (last upload 2012). Not a useful dependency.

### `mcmc` + `dirichlet` — active MCMC, different approach

Schrempf (active, last release 2024). A modern sampler supporting MHG, MC3, HMC, NUTS. Depends on
his `dirichlet` package for the multivariate Dirichlet. These cover the same distributions but via
MCMC, not conjugate marginalization. Worth watching for any future MCMC fallback path, but not for
the primary delayed-sampling approach.

### `statistics-dirichlet` — dead

Lessa (last built 2016, docs unavailable). Dirichlet density and mixture fitting. Not a viable
dependency.

### `mwc-probability` — sampling utility, no inference

Tobin & Zocca. Thin layer over `mwc-random` with a distribution functor. Useful for writing
generative models; provides no inference machinery. Already superseded by `monad-bayes` in this
project.

## Summary

**No package on Hackage performs analytic Rao-Blackwellization via a dynamic conjugate graph.**
The `delayed-sampling` port in this repository is novel Haskell infrastructure. The pomological
application built on top of it has no precedent in Haskell either.

The combination of (`monad-bayes` for the sampler layer) + (`delayed-sampling` for analytic
marginalization) is the full stack. Nothing needs to be borrowed or replaced from the ecosystem
for the core inference path.
