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
- **Every item carries YAML frontmatter.** `todo/SCHEMA.md` is the field-by-field contract — read it
  there, do not restate it here; the two would drift.
- **`size` is `S`/`M`/`L`**: one revision, one arc, or multiple arcs (may need subdivision, research,
  a decision with the maintainer, or user testing). Every `size` carries a `size_evidence`: a
  verbatim quote from the item's own body, or exactly `"no cue in source file"`. Where a file gives
  no cue, take the **larger** of the two candidate sizes rather than inferring effort from tone —
  and check the quote does not straddle a line break before writing it down, since `todo/` prose is
  hard-wrapped at ~95 columns; two todos in the arc that built this schema tripped over exactly
  that.
- **`milestone` is a ladder, not a set of groups.** Each rung is a state the *project* reaches, so an
  item's milestone says when it becomes necessary, not which bucket it belongs to. An item normally
  carries one entry; more than one means it genuinely spans rungs (`milestone_note` says which part
  of its scope belongs to which — see `todo/SCHEMA.md`).

  | # | Reached when |
  |---|---|
  | 1 | We can build a seed corpus |
  | 2 | I can record a real apple manually |
  | 3 | The model fits and is measured |
  | 4 | A recorded apple gets a prediction that is not nonsense |
  | 5 | I can record with a pomologist |
  | 6 | The real v1 network runs |
  | 7 | Library cleanup — and the GitHub port, see below |
  | 8 | Orchard, the mobile-first web frontend |

- **`todo/README.md` is generated below its marker comment**
  (`<!-- GENERATED INDEX — ... -->`) by `todo/check.sh --write-index`: open items grouped by
  milestone in ladder order, topologically sorted so a `needs` target lists above its dependent,
  then a `## Closed` section. Never hand-edit at or below that marker; edit the prose above it, then
  regenerate.
- **`R` numbers were removed deliberately and must not be reintroduced under any new numbering.**
  `model-v1-delayed-sampling-requirements.md`, which used to number them R1–R15, was dissolved into
  the items it numbered. Only a provenance heading or `provenance:` value may still mention a
  number, because it names a historical source, not a live cross-reference.
- **Supersede with a banner blockquote at the top of the file; do not delete the file.** When a
  decision overturns an item, say so in a `>` banner naming what survives and what does not. Several
  items have been corrected twice, and the corrections are load-bearing — an agent that silently
  rewrites history will re-make a mistake the backlog already caught. Deleting genuinely dead
  *detours* within a file is fine and encouraged; say in the banner what was removed.
- **The backlog ports to GitHub issues at milestone 7, not before.** It was going to be ported
  earlier; that plan was reversed after measuring the overhead — eight of its ten todos existed only
  because the target was GitHub (a manifest to make issue creation reviewable, a script to read it
  back, a verification pass against live state), and all eight collapse once the tracker is files in
  the repo instead, reviewable as an ordinary diff. Porting later is mechanical because the judgement
  already lives in the frontmatter; `todo/SCHEMA.md` carries the field-to-GitHub-field mapping so the
  port script needs none of its own. If the plan directory that built this schema is still around,
  its `research/abandoned-github-port.md` and `decisions.md` have the full argument.
- Run `nix develop -c todo/check.sh` after any edit to `todo/` — `nix develop` because `yq`, which it
  needs to parse frontmatter, is only on `PATH` inside the shell. It validates every item's
  frontmatter against `todo/SCHEMA.md` and fails if `todo/README.md`'s generated index has drifted
  (the message names `--write-index` to fix it). Two gaps: it never checks markdown links in prose
  bodies, only `needs`/`parent` slugs, and it checks a field's type only once the field is there, so
  a missing field never errors — a missing `status` or `milestone` silently vanishes from every
  section of the generated index, while a missing `pkg` or `size` just leaves that row's cell blank
  or `?`. Until presence is checked, also run the old link-and-orphan one-liner by hand; its
  `ORPHAN: SCHEMA.md` is expected, not a real orphan:

      cd todo && rg -o --no-filename '\]\(([a-z0-9./-]+\.md)\)' -r '$1' *.md | sort -u \
        | while read f; do [ -f "$f" ] || echo "MISSING: $f"; done
      for f in *.md; do [ "$f" = README.md ] && continue
        rg -q "\($f\)" README.md || echo "ORPHAN: $f"; done
