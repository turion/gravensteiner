# Hacking notes

- **HLS is available** in the devShell and usable, but its diagnostics may be **stale** —
  cross-check against `cabal build -v0 all` before trusting them.
- **Do not run `fourmolu`.** Formatting is handled manually by the maintainer; leave
  whitespace alone even when `fourmolu --mode check` fails.
- `jj agent-log` already embeds `-n10`, so passing another `-n`/`--limit` fails with
  `the argument '--limit <LIMIT>' cannot be used multiple times`. Call it bare.
- `cabal build all` does **not** build test suites; use `cabal build -v0 --enable-tests all`
  (or `cabal test -v0 all`) when a change can break test modules.
- In `delayed-sampling`'s test suite, wrap graph operations in `checked`
  (`action <* ensureConsistency`) rather than calling them bare, so every test also checks
  the graph invariants. `ensureConsistency` walks the whole graph, which is why library code
  does not call it.
