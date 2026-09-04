# Working on the `todo/` backlog

Read this before editing anything under `todo/`. It is split out of the repo root's `AGENTS.md`,
which every agent loads, because it only concerns whoever is planning or grooming the backlog.

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
  on a dangling link or an unexpected orphan.
- **Both scripts treat `README.md`, `SCHEMA.md`, this file and `CLAUDE.md` as "not items"** and
  skip them: they carry no frontmatter and are not linked from `README.md`'s generated index. Any
  *other* new `.md` file added under `todo/` is therefore required to be a well-formed item — if
  you need another non-item document here, add its basename to the `README|SCHEMA|AGENTS|CLAUDE`
  cases in `check.sh` (two of them) and to the `not_an_item` list in `check-links.sh`, in the same
  revision.
- **`todo/CLAUDE.md` is a one-line `@AGENTS.md` import, and must stay.** Claude Code auto-loads a
  nested `CLAUDE.md` when it reads a file in that directory, but does *not* auto-load a nested
  `AGENTS.md`; the shim is what makes this guide load by itself for anyone working in `todo/`.
