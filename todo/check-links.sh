#!/usr/bin/env bash
# Check the todo/ backlog's cross-references: every `](foo.md)` link in an item file must point at
# a file that exists, and every item file (other than README.md and SCHEMA.md) must be linked from
# README.md. This is the authoritative, asserting form of the rule documented in AGENTS.md; both
# `.github/workflows/ci.yml`'s `todo-backlog` job and AGENTS.md's link-and-orphan note point here
# rather than keeping their own copy.
#
# Exit status: 0 on a clean tree (an ORPHAN: SCHEMA.md line may still print — that one is expected,
# since SCHEMA.md is the frontmatter contract, not a backlog item, and so is never linked from
# README.md); non-zero on a dangling link, an unexpected orphan, or a `grep` failure that is not
# just "no matches".
#
# Uses grep's GNU `-P` (PCRE) extension, which is not portable to macOS's BSD grep. That is fine
# here: this only runs on the `ubuntu-latest` CI runner and the maintainer's Linux machine.
set -euo pipefail

cd "$(dirname "$0")"

# grep exits 1 for "no matches" (not an error here) and >1 for a real failure; disable errexit
# just for this call so we can tell them apart.
set +e
extracted=$(grep -ohP '(?<=\]\()[a-z0-9./-]+\.md(?=\))' *.md)
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

status=0
for f in *.md; do
  [ "$f" = README.md ] && continue
  if ! grep -q "($f)" README.md; then
    if [ "$f" = SCHEMA.md ]; then
      # SCHEMA.md is not an item, so it is never linked from README.md. Expected, and the only
      # filename this exemption may cover.
      echo "ORPHAN: SCHEMA.md (expected, not a failure)"
    else
      echo "ORPHAN: $f"
      status=1
    fi
  fi
done
if [ "$status" -ne 0 ]; then
  echo "todo/check-links.sh: unexpected orphan(s) found" >&2
fi
exit "$status"
