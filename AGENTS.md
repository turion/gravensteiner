# Hacking notes

This file is loaded for every agent, so it holds only what every agent needs. The rest lives in
two role guides — read the relevant one before starting that kind of work:

| Before | Read |
|---|---|
| editing anything under `todo/` | [`todo/AGENTS.md`](todo/AGENTS.md) |
| pushing, or touching CI, formatting or the flake | [`.github/AGENTS.md`](.github/AGENTS.md) |

Each of those two directories also holds a one-line `CLAUDE.md` reading `@AGENTS.md`. **Do not
delete them**: Claude Code auto-loads a nested `CLAUDE.md` when it reads a file in that directory,
but does *not* auto-load a nested `AGENTS.md` — the shim is what makes the guide arrive on its own
rather than only when someone follows the table above. Measured, not assumed.

## The house gates

Every sealed revision must pass both of these, and the `-fdev` is not optional — it is what turns
`-Wall` into `-Werror`, so a warning fails the gate on the revision that introduces it rather than
surfacing later as a CI failure on a pushed branch:

    nix develop -c cabal build -v0 --enable-tests all -fdev
    nix develop -c cabal test -v0 all -fdev

`cabal build all` on its own does **not** build test suites, which is what `--enable-tests` is
for. Why `-Werror` sits behind a flag instead of being always on, and which warnings
`gravensteiner`'s executable stanza still downgrades, is in `.github/AGENTS.md`.

## For every agent

- **HLS is available** in the devShell and usable, but its diagnostics may be **stale** —
  cross-check against the build gate above before trusting them.
- **No agent spends effort on formatting.** Formatting is applied *mechanically* by `jj fix` over
  the stack, once, immediately before pushing at the end of an arc — never by a coder hand-adjusting
  whitespace. CI enforces `fourmolu --mode check` on what is pushed, so a mid-arc revision may be
  fourmolu-dirty and that is not a defect. The `jj fix` setup has two caveats on this machine; both
  are in `.github/AGENTS.md`, and they matter only to whoever runs it before pushing.
- **Adding a `build-depends` entry can break `nix develop` itself**, because haskell-flake builds
  every dependency from nixpkgs including its test suite, and several fail on ghc912. The symptom is
  `error: builder for '/nix/store/...-<pkg>.drv' failed` followed by `N out of M tests failed`, and
  it blocks the *shell*, not just the build — so no `cabal` command can run at all. Two fixes: one
  line in `flake.nix` next to the existing `sandwich.check = false;` (haskell-flake's spelling of
  nixpkgs' `dontCheck`), or drop the dependency. Seen so far: `sandwich`, fixed with `check = false`;
  and `optics` (3 of 127 inspection-testing tests fail), fixed by removing it from the cabal file —
  so do not expect an `optics.check` line to exist. `dimensional` 1.6.2 was checked before planning:
  it builds clean from this flake's nixpkgs on ghc912 with its test suite (exit 0), and that build
  covers its whole test-checked dependency closure, so it needs no `flake.nix` line.
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
