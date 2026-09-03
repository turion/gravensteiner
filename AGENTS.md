# Hacking notes

- **HLS is available** in the devShell and usable, but its diagnostics may be **stale** —
  cross-check against `cabal build -v0 all` before trusting them.
- **No agent spends effort on formatting.** Formatting is applied *mechanically* by `jj fix` over
  the stack, once, immediately before pushing at the end of an arc — never by a coder hand-adjusting
  whitespace. CI enforces `fourmolu --mode check` on what is pushed, so a mid-arc revision may be
  fourmolu-dirty and that is not a defect. `fix.tools.fourmolu` is already configured on this
  machine (`fourmolu --stdin-input-file $path` over `glob:**/*.hs`) — see `jj config list
  --include-defaults` — so a plain `jj fix` picks it up with no further setup.
- **This machine's `jj fix` also has a foreign `hlint` tool configured**, applying another
  project's automatic refactorings to every `.hs` file
  (`fix.tools.hlint.command = ["hlint", "-", "--refactor", "-h",
  "/home/turion/heilmannsoftware/connect/.hlint.yaml"]` over `glob:**/*.hs`) — unrelated to this
  repo and liable to undo deliberate hlint decisions made here. `jj fix` has no `--tool` flag, so
  the only way to scope it to fourmolu is disabling that tool at repo scope:

      jj config set --repo fix.tools.hlint.enabled false

  This writes to a config file *outside* the repository, under a per-clone hash — there is no
  `.jj/repo/config.toml` to check in, so a fresh clone must run the command again. Find the file
  with `jj config path --repo`; do not hard-code the path, since the hash differs per clone.
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

# Working on the `todo/` backlog

The backlog is prose-heavy on purpose: it records *why* each decision was made, because most of the
decisions rest on statistical reasoning that nothing has measured yet. Conventions worth following,
since breaking them costs more than it saves:

- **One file per item**, opening with `## Why it matters` and closing with `## Done when`, optionally
  followed by provenance sections recording where moved prose came from. Three items predate this
  rule and close on something else instead: `apple-model-zero-colours-are-fatal.md` (`## What
  survives, and what does not`), `haskell-library-landscape.md` (`## Summary`), and
  `value-affine-normal-form.md`, which has no `## Done when` section at all and closes on its own
  `## From the v1 requirements document (R2)` heading.
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
- Run `nix develop -c todo/check.sh` after any edit to `todo/` — `nix develop` because `yq`,
  which it needs to parse frontmatter, is only on `PATH` inside the shell. It validates every item's
  frontmatter against `todo/SCHEMA.md`: a file with no frontmatter block, an unknown or wrongly-typed
  field, and a missing required field (`status`/`pkg` always; `milestone`/`size`/`size_evidence`
  on open items; `closed_by` on a closed item; `milestone_note` on a multi-milestone one) all
  fail it now. It also fails if `todo/README.md`'s generated index has drifted (`--write-index`
  fixes it). It still never checks markdown links in prose bodies, only `needs`/`parent` slugs,
  nor `provenance`'s presence — nothing in the frontmatter marks which items need one. Also run
  `todo/check-links.sh` by hand — it is the authoritative form of the link-and-orphan rule (CI's
  `todo-backlog` job calls the same script) and it **asserts**, not just reports: it exits non-zero
  on a dangling link or an unexpected orphan. Its `ORPHAN: SCHEMA.md` is expected, not a real
  orphan.

# Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request;
`.github/workflows/update-flake-lock.yml` runs weekly (and on `workflow_dispatch`) to open a pull
request bumping `flake.lock`; `.github/dependabot.yml` opens pull requests for stale GitHub
Actions daily.

- **What the two `ci.yml` halves check.** The cabal half (`build-cabal`, over the GHC matrix
  `generateMatrix` derives from the cabal file's `tested-with`) verifies the version range the
  cabal files advertise against compilers other than the ambient one. The nix half
  (`check-flake`, `build-flake`) verifies the flake, including the `nix develop` shell that
  haskell-flake builds from every dependency's nixpkgs derivation, test suite included. Read the
  direction carefully: when *this repo* adds a `build-depends` entry, the failure mode documented
  above (a dependency's own test suite failing under haskell-flake, e.g. `sandwich` or `optics`)
  is caught **locally first**, by the house build gate `nix develop -c cabal build -v0
  --enable-tests all`, on the very revision that adds the entry — CI cannot beat that. What CI
  adds is the other direction: `update-flake-lock.yml`'s weekly pull request, where nixpkgs moves
  underneath an *unchanged* dependency list. Nobody runs `nix flake update` by hand on a schedule,
  so that failure has no local gate at all; `build-flake` running on that pull request is the only
  thing that catches it.
- **How to see a run.** After `jj git push`, `gh run list -L 1` (or `gh run watch`) shows the push-
  triggered `ci.yml` run. Neither bot pull request stream produces terminal output, and they do not
  notify alike: Dependabot's PRs are authored by `dependabot[bot]`, and the owner auto-watches
  repositories he created, so those **do** notify him. The weekly `update-flake-lock` PR is authored
  by his own classic PAT instead, and GitHub's "your own updates" notifications are off by default —
  so **that** stream is the silent one. `update-flake-lock`'s `pr-assignees`/`pr-reviewers` inputs
  are a one-line way to make it surface, if he wants that; neither is set today. Find either stream
  with `gh pr list`, then check a given one with `gh pr checks <n>`.
- **`.nix` files have no local formatting gate.** `check-flake` runs `nix fmt . --accept-flake-config`
  (`nixpkgs-fmt`, the flake's `formatter` output) and fails on drift, but `jj fix` only covers `.hs`
  and `.cabal`, so a `flake.nix` edit — the next `check = false` line, say — only turns that required
  check red once it has been pushed. There is no working `jj fix` route to close this today:
  `nixpkgs-fmt` is not on `PATH`, neither in the ambient shell nor inside `nix develop`
  (`command -v nixpkgs-fmt` fails both ways) — it is built only as the flake's `formatter` output,
  not part of the devShell, so a `fix.tools.nixpkgs-fmt` entry naming it bare would just fail to find
  the binary. Adding it to the devShell would fix that, but is a `flake.nix` change. Until then, run
  **`nix fmt .`** by hand before pushing whenever a `flake.nix` edit might need it — the same command
  CI runs, so a local pass means the check will pass too.
- **The poisoned-eval-cache symptom.** Concurrent `nix` invocations on this machine can leave a
  partial row in the eval cache. The symptom looks exactly like a broken flake: `nix develop`
  starts failing with `expected flake output attribute 'devShells.x86_64-linux.default' to be a
  derivation or path but found a set`. The fix is `rm -rf ~/.cache/nix/eval-cache-v5`, confirmed
  by `nix develop --no-eval-cache -c true` succeeding — it is a workaround, not a repair, so it can
  recur. Run `nix` commands one at a time to avoid triggering it.
- **The `dev` flag.** `-Wall` is always on in both packages; `-Werror` sits behind `flag dev`
  (`default: False`), and `ci.yml` passes `-fdev` on its cabal build and test steps. The local
  gates deliberately do **not** pass `-fdev`, so a newer GHC's new warning class cannot turn a
  working copy red. `gravensteiner`'s executable stanza carries three matching downgrades inside
  its own `if flag(dev)` block — `-Wno-error=type-defaults`, `-Wno-error=unused-matches`,
  `-Wno-error=unused-imports` — because `app/Main.hs` is the superseded precursor documented above
  and is not being fixed; all three go when that file does.
