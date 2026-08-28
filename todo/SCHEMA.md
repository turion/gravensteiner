# Frontmatter schema

Every item file under `todo/` — every `.md` file except this one and `README.md` — carries a YAML
frontmatter block at the very top: a line reading exactly `---`, the YAML, then a second line
reading exactly `---`, before the file's Markdown body. `todo/check.sh` requires that opening line
literally; a file with no frontmatter block is counted as such rather than parsed.

A **slug** is an item file's filename without the `.md` extension, e.g.
`value-affine-normal-form.md` has slug `value-affine-normal-form`. Slugs are how one item refers to
another (`needs`, `parent`, and links inside prose) and never change once something else points at
them.

`todo/check.sh` converts the extracted block with `yq -o=json` and asserts on the result with `jq`;
see that file for exactly what it enforces. This document is the contract those assertions
implement, and the one seven later todos write frontmatter against.

## Fields

| Field | Type | Required |
|---|---|---|
| `status` | `"open"` or `"closed"` | Always. |
| `milestone` | list of integers, each 1–8 | On open items. Absent on closed items — a closed item does not occupy a rung. |
| `milestone_note` | string | When `milestone` has more than one entry. Names which entry the item's remaining scope belongs to (see `conjugate-pairs-beyond-normal` for the worked example: one pair is milestone 1, the rest are milestone 6). Absent otherwise. |
| `size` | `"S"`, `"M"` or `"L"` | On open items. |
| `size_evidence` | string | Wherever `size` is present. Either a verbatim quote from that item's own body, or exactly the literal string `"no cue in source file"`. When the file gives no cue, take the *larger* of the two candidate sizes rather than inferring effort from tone. |
| `pkg` | list of `"delayed-sampling"` / `"gravensteiner"` | Always. May name one or both. |
| `kind` | `"decision"` | On an item that closes (or, once closed, closed) by a decision being written down in the file rather than by a code diff landing. May be present while the item is still `open` and the decision has not been made yet — that is what tells a reviewer not to demand a diff from it. |
| `needs` | list of slugs | Optional. Other items that must land first. |
| `parent` | slug | Optional. The item this one is filed under (a native GitHub sub-issue relation at port time). |
| `closed_by` | string | When `status: closed`. Either the revision that closed the item (short hash and subject, e.g. from `git log --format='%h %s'`), or a plain statement that none could be identified — never a guess. |
| `provenance` | string | On an item carved out of a document that was dissolved into several items (`model-v1-review.md`, `model-v1-delayed-sampling-requirements.md`) or restored from history after being closed by file deletion. Says which source, section or tier the item came from, in enough detail that the carve-up can be audited without re-reading the source. |

No other field is valid; `todo/check.sh` rejects anything outside this table by name, and rejects a
present field of the wrong type or (for `status`, `size`, `pkg`'s entries, `kind`) the wrong value.

## The milestone ladder

`milestone` refers to the eight-rung table in the plan's `README.md` (1 seed corpus, 2 record an
apple manually, 3 model fits and is measured, 4 prediction that is not nonsense, 5 record with a
pomologist, 6 the real v1 network, 7 library cleanup and the GitHub port, 8 Orchard, the web
frontend). An item normally carries one entry; a list of more than one means the item genuinely
spans rungs and, at port time, is the signal that it must be split into two issues — `milestone_note`
records which part of the item's scope belongs to which entry.

## A worked example

```yaml
---
status: open
milestone: [6]
size: L
size_evidence: "Item 1 below is therefore not a stepping stone towards the apple model; it is the bulk of it."
pkg: [delayed-sampling]
needs: [vector-valued-variables-and-dirichlet]
---
```

A closed item that recorded a decision, with no milestone:

```yaml
---
status: closed
kind: decision
pkg: [delayed-sampling]
closed_by: "a1b2c3d russet is a texture, not a colour"
---
```

## Why this shape, not GitHub issues directly

This backlog stays local; the frontmatter is shaped so that a later port to GitHub issues (deferred
to milestone 7 — see `research/abandoned-github-port.md` if this plan directory is still around, and
`decisions.md` regardless) is a mechanical read of these fields rather than a task carrying its own
judgement:

| Frontmatter | GitHub |
|---|---|
| `status` | issue state |
| `milestone` | milestone — a list means the item is split into two issues first |
| `size` | a `size/*` label |
| `pkg` | `pkg/*` label(s) |
| `kind: decision` | a `decision` label |
| `needs` | "Blocked by #N", and board order |
| `parent` | native sub-issue link |
| `closed_by` | closing comment |
| body | issue body |
