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
  it blocks the *shell*, not just the build — so no `cabal` command can run at all. Two fixes: one
  line in `flake.nix` next to the existing `sandwich.check = false;` (haskell-flake's spelling of
  nixpkgs' `dontCheck`), or drop the dependency. Seen so far: `sandwich`, fixed with `check = false`;
  and `optics` (3 of 127 inspection-testing tests fail), fixed by removing it from the cabal file —
  so do not expect an `optics.check` line to exist.
- In `delayed-sampling`'s test suite, wrap graph operations in `checked`
  (`action <* ensureConsistency`) rather than calling them bare, so every test also checks
  the graph invariants. `ensureConsistency` walks the whole graph, which is why library code
  does not call it.

# Where things stand

- `gravensteiner/src/Gravensteiner/Model.hs` is the **real observation schema** (v1, with a
  `version :: Int` constant for migrations). `gravensteiner/app/Main.hs` is a **superseded
  precursor** slated for deletion — do not fix things in it; check `todo/apple-model-cleanups.md`
  for the findings that transfer instead.
- `cabal run gravensteiner` **crashes** with `System.Random.MWC.Distributions.categorical: bad
  weights!`. This is known, diagnosed in `todo/apple-model-zero-colours-are-fatal.md`, and the
  maintainer has said not to worry about it — it dies with `Main.hs`.
- `gravensteiner` has a `library` and an `executable` and **no `test-suite`**. That is the gap
  tracked in `todo/no-evaluation-harness.md`, not an oversight to route around. `delayed-sampling`
  does have one, and it is the model for style.
- `todo/README.md` names the **next planning session** at the top. Start there.

# Working on the `todo/` backlog

The backlog is prose-heavy on purpose: it records *why* each decision was made, because most of the
decisions rest on statistical reasoning that nothing has measured yet. Conventions worth following,
since breaking them costs more than it saves:

- **One file per item**, opening with `## Why it matters` and closing with `## Done when`.
- **Cite functions, types and fields by name, never by line number** — reformatting invalidates line
  numbers and these files outlive the code they describe.
- **`todo/README.md` is the index.** Every file must be linked from it; no orphans. Groups are sorted
  by dependency, and each row carries its `R` number where it has one.
- **`todo/model-v1-delayed-sampling-requirements.md` holds R1–R15 and is the spine.** Cross-reference
  by R number rather than restating a requirement in a second place.
- **Supersede with a banner blockquote at the top of the file; do not delete the file.** When a
  decision overturns an item, say so in a `>` banner naming what survives and what does not. Several
  items have been corrected twice, and the corrections are load-bearing — an agent that silently
  rewrites history will re-make a mistake the backlog already caught. Deleting genuinely dead
  *detours* within a file is fine and encouraged; say in the banner what was removed.
- Verify links and orphans after any edit to `todo/`:

      cd todo && rg -o --no-filename '\]\(([a-z0-9./-]+\.md)\)' -r '$1' *.md | sort -u \
        | while read f; do [ -f "$f" ] || echo "MISSING: $f"; done
      for f in *.md; do [ "$f" = README.md ] && continue
        rg -q "\($f\)" README.md || echo "ORPHAN: $f"; done
