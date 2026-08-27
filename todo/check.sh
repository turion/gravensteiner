#!/usr/bin/env bash
# Validate the YAML frontmatter of every item file under todo/ against todo/SCHEMA.md.
#
# Usage: todo/check.sh [DIR]
#   DIR defaults to this script's own directory, so `nix develop -c todo/check.sh` run from the
#   repo root checks todo/. Pass a different DIR only to point the validator at a scratch fixture
#   directory while testing malformed frontmatter; the maintainer and the arc always run it with
#   no argument.
#
# Needs the Go build of `yq` (mikefarah/yq, v4) and `jq`, both on PATH inside `nix develop`.
set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "todo/check.sh: 'yq' not found on PATH. Run this inside the shell: nix develop -c todo/check.sh" >&2
  exit 1
fi

dir="${1:-$(dirname "$0")}"

known_fields_json='["status","milestone","milestone_note","size","size_evidence","pkg","kind","needs","parent","closed_by","provenance"]'

# The universe of valid slugs `needs`/`parent` may point at: every item file's basename, minus the
# two files that are not items.
slugs_json=$(
  shopt -s nullglob
  for f in "$dir"/*.md; do
    base=$(basename "$f" .md)
    case "$base" in
      README|SCHEMA) continue ;;
    esac
    printf '%s\n' "$base"
  done | jq -R . | jq -s .
)

# One jq program, run once per file against that file's extracted frontmatter (as JSON), the known
# field list, the slug universe, and the file's own body (frontmatter stripped) for the
# size_evidence substring check.
read -r -d '' jq_program <<'JQ' || true
def is_int: (type == "number") and (. == (. | floor));

def unknown_errors:
  if ($fm | type) != "object" then
    ["frontmatter is not a YAML mapping"]
  else
    [ (($fm | keys) - $known)[] | "unknown field: \(.)" ]
  end;

def type_errors:
  [
    (if ($fm | has("status")) then
       (if ($fm.status | type) != "string" or (["open","closed"] | index($fm.status)) == null
        then "status: must be the string \"open\" or \"closed\""
        else empty end)
     else empty end),
    (if ($fm | has("milestone")) then
       (if ($fm.milestone | type) != "array"
        then "milestone: must be a list of integers"
        elif ([$fm.milestone[] | select((is_int | not) or . < 1 or . > 8)] | length) > 0
        then "milestone: must be a list of integers 1-8"
        else empty end)
     else empty end),
    (if ($fm | has("milestone_note")) then
       (if ($fm.milestone_note | type) != "string"
        then "milestone_note: must be a string"
        else empty end)
     else empty end),
    (if ($fm | has("size")) then
       (if ($fm.size | type) != "string" or (["S","M","L"] | index($fm.size)) == null
        then "size: must be \"S\", \"M\" or \"L\""
        else empty end)
     else empty end),
    (if ($fm | has("size_evidence")) then
       (if ($fm.size_evidence | type) != "string"
        then "size_evidence: must be a string"
        else empty end)
     else empty end),
    (if ($fm | has("pkg")) then
       (if ($fm.pkg | type) != "array"
        then "pkg: must be a list"
        elif ([$fm.pkg[] | select(type != "string" or (. as $p | ["delayed-sampling","gravensteiner"] | index($p)) == null)] | length) > 0
        then "pkg: entries must be \"delayed-sampling\" or \"gravensteiner\""
        else empty end)
     else empty end),
    (if ($fm | has("kind")) then
       (if $fm.kind != "decision"
        then "kind: must be \"decision\""
        else empty end)
     else empty end),
    (if ($fm | has("needs")) then
       (if ($fm.needs | type) != "array" or ([$fm.needs[] | select(type != "string")] | length) > 0
        then "needs: must be a list of slug strings"
        else empty end)
     else empty end),
    (if ($fm | has("parent")) then
       (if ($fm.parent | type) != "string"
        then "parent: must be a slug string"
        else empty end)
     else empty end),
    (if ($fm | has("closed_by")) then
       (if ($fm.closed_by | type) != "string"
        then "closed_by: must be a string"
        else empty end)
     else empty end),
    (if ($fm | has("provenance")) then
       (if ($fm.provenance | type) != "string"
        then "provenance: must be a string"
        else empty end)
     else empty end)
  ];

def dangling_errors:
  ( (if ($fm.needs? // null) != null and ($fm.needs | type) == "array" then $fm.needs else [] end)
    + (if ($fm.parent? // null) != null and ($fm.parent | type) == "string" then [$fm.parent] else [] end)
  )
  | map(select(type == "string"))
  | map(select(. as $s | ($slugs | index($s)) == null))
  | map("references unknown slug: \(.)");

def milestone_note_errors:
  if ($fm.milestone? // null) != null
     and ($fm.milestone | type) == "array"
     and ($fm.milestone | length) > 1
     and (($fm | has("milestone_note")) | not)
  then ["milestone has more than one entry but no milestone_note"]
  else [] end;

def closed_by_errors:
  if ($fm.status? // null) == "closed" and (($fm | has("closed_by")) | not)
  then ["status: closed but no closed_by"]
  else [] end;

def size_evidence_errors:
  if ($fm | has("size_evidence")) and ($fm.size_evidence | type) == "string" then
    ($fm.size_evidence) as $ev |
    if $ev == "no cue in source file" then []
    elif ($body | contains($ev)) then []
    else ["size_evidence is neither \"no cue in source file\" nor a substring of the file's own body"]
    end
  else [] end;

(unknown_errors + type_errors + dangling_errors + milestone_note_errors + closed_by_errors + size_evidence_errors)
| .[]
JQ

no_frontmatter=0
error_count=0

shopt -s nullglob
for f in "$dir"/*.md; do
  base=$(basename "$f" .md)
  case "$base" in
    README|SCHEMA) continue ;;
  esac

  first_line=$(head -n1 "$f" || true)
  if [ "$first_line" != "---" ]; then
    no_frontmatter=$((no_frontmatter + 1))
    continue
  fi

  if ! fm_json=$(yq --front-matter=extract -o=json "$f" 2>/dev/null); then
    echo "todo/check.sh: $base.md: malformed YAML frontmatter (yq could not parse it)" >&2
    error_count=$((error_count + 1))
    continue
  fi

  body=$(awk 'BEGIN { n = 0 } /^---$/ { n++; next } n >= 2 { print }' "$f")

  errors=$(jq -n \
    --argjson fm "$fm_json" \
    --argjson known "$known_fields_json" \
    --argjson slugs "$slugs_json" \
    --arg body "$body" \
    -r "$jq_program")

  if [ -n "$errors" ]; then
    while IFS= read -r msg; do
      echo "todo/check.sh: $base.md: $msg" >&2
      error_count=$((error_count + 1))
    done <<< "$errors"
  fi
done

echo "todo/check.sh: $no_frontmatter file(s) under $dir have no frontmatter yet."

if [ "$error_count" -gt 0 ]; then
  echo "todo/check.sh: $error_count error(s)." >&2
  exit 1
fi

exit 0
