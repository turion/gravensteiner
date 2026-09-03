#!/usr/bin/env bash
# Check the todo/ backlog's cross-references: every `](foo.md)` link in an item file must point at
# a file that exists, and every item file must be linked from README.md. This is the authoritative,
# asserting form of the rule documented in todo/AGENTS.md; both `.github/workflows/ci.yml`'s
# `todo-backlog` job and that file's link-and-orphan note point here rather than keeping their own
# copy. The files that are not items — see `not_an_item` below — are exempt from the orphan check.
#
# Exit status: 0 and no output on a clean tree; non-zero on a dangling link, an orphan, or a `grep`
# failure that is not just "no matches".
#
# Uses grep's GNU `-P` (PCRE) extension, which is not portable to macOS's BSD grep. That is fine
# here: this only runs on the `ubuntu-latest` CI runner and the maintainer's Linux machine.
set -euo pipefail

cd "$(dirname "$0")"

# grep exits 1 for "no matches" (not an error here) and >1 for a real failure; disable errexit
# just for this call so we can tell them apart.
set +e
# The character class covers uppercase too: the two filenames this script special-cases below,
# README.md and SCHEMA.md, are themselves uppercase, so a lowercase-only class would silently
# skip validating a link that pointed at either of them.
extracted=$(grep -ohP '(?<=\]\()[A-Za-z0-9._/-]+\.md(?=\))' ./*.md)
rc=$?
set -e
if [ "$rc" -gt 1 ]; then
  echo "todo/check-links.sh: link extraction failed (grep exit $rc)" >&2
  exit "$rc"
fi

missing=""
if [ -n "$extracted" ]; then
  missing=$(printf '%s\n' "$extracted" | sort -u \
    | while read -r f; do [ -f "$f" ] || echo "MISSING: $f"; done)
fi
if [ -n "$missing" ]; then
  printf '%s\n' "$missing"
  echo "todo/check-links.sh: dangling link(s) found" >&2
  exit 1
fi

# The files under todo/ that are not backlog items: they carry no frontmatter and are never linked
# from README.md's generated index, so neither the orphan check below nor check.sh's frontmatter
# validation applies to them. Keep this in step with the `README|SCHEMA|AGENTS` cases in check.sh.
not_an_item="README.md SCHEMA.md AGENTS.md"

status=0
for f in ./*.md; do
  f=${f#./}
  case " $not_an_item " in *" $f "*) continue ;; esac
  # -F because a filename is a literal, not a pattern: unescaped `.` would match any character.
  if ! grep -qF "($f)" README.md; then
    echo "ORPHAN: $f"
    status=1
  fi
done
if [ "$status" -ne 0 ]; then
  echo "todo/check-links.sh: unexpected orphan(s) found" >&2
fi
exit "$status"
