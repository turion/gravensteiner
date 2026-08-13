# Hacking notes

- **HLS is available** in the devShell and usable, but its diagnostics may be **stale** —
  cross-check against `cabal build -v0 all` before trusting them.
- **Do not run `fourmolu`.** Formatting is handled manually by the maintainer; leave
  whitespace alone even when `fourmolu --mode check` fails.
- `jj agent-log` already embeds `-n10`, so passing another `-n`/`--limit` fails with
  `the argument '--limit <LIMIT>' cannot be used multiple times`. Call it bare.
- `cabal build all` does **not** build test suites; use `cabal build -v0 --enable-tests all`
  (or `cabal test -v0 all`) when a change can break test modules.
- **Adding a `build-depends` entry can break `nix develop` itself**, because haskell-flake builds
  every dependency from nixpkgs including its test suite, and several fail on ghc912. The symptom is
  `error: builder for '/nix/store/...-<pkg>.drv' failed` followed by `N out of M tests failed`, and
  it blocks the *shell*, not just the build — so no `cabal` command can run at all. The fix is one
  line in `flake.nix` next to the existing `sandwich.check = false;`, which is haskell-flake's
  spelling of nixpkgs' `dontCheck`. Seen so far: `sandwich`, and `optics` (3 of 127
  inspection-testing tests fail).
- In `delayed-sampling`'s test suite, wrap graph operations in `checked`
  (`action <* ensureConsistency`) rather than calling them bare, so every test also checks
  the graph invariants. `ensureConsistency` walks the whole graph, which is why library code
  does not call it.
