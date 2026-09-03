#!/usr/bin/env bash
# Validate the YAML frontmatter of every item file under todo/ against todo/SCHEMA.md, and check
# (or regenerate) todo/README.md's generated index against that frontmatter.
#
# Usage: todo/check.sh [--write-index] [DIR]
#   DIR defaults to this script's own directory, so `nix develop -c todo/check.sh` run from the
#   repo root checks todo/. Pass a different DIR only to point the validator at a scratch fixture
#   directory while testing malformed frontmatter; the maintainer and the arc always run it with
#   no argument.
#
#   Without --write-index: reports frontmatter errors as before, and additionally treats a
#   README.md whose generated section (everything at or below the marker comment) does not match
#   what the current frontmatter would produce as another error class — exit non-zero, with a
#   message to run --write-index. Skipped when DIR has no README.md (the fixture-directory case).
#
#   With --write-index: regenerates README.md's generated section in place, leaving everything
#   above the marker comment untouched. Requires the marker to already be present; it does not
#   invent one. Running it twice in a row produces no further change.
#
# Needs the Go build of `yq` (mikefarah/yq, v4) and `jq`, both on PATH inside `nix develop`.
set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "todo/check.sh: 'yq' not found on PATH. Run this inside the shell: nix develop -c todo/check.sh" >&2
  exit 1
fi

write_index=0
dir=""
for arg in "$@"; do
  case "$arg" in
    --write-index) write_index=1 ;;
    *) dir="$arg" ;;
  esac
done
dir="${dir:-$(dirname "$0")}"

# The marker below which todo/README.md's index is generated wholesale; everything above it is
# hand-written prose that regeneration never touches.
index_marker='<!-- GENERATED INDEX — updated by `todo/check.sh --write-index`; do not hand-edit below this line -->'

known_fields_json='["status","milestone","milestone_note","size","size_evidence","pkg","kind","needs","parent","closed_by","provenance"]'

# The universe of valid slugs `needs`/`parent` may point at: every item file's basename, minus the
# three files that are not items (README.md, SCHEMA.md, AGENTS.md).
slugs_json=$(
  shopt -s nullglob
  for f in "$dir"/*.md; do
    base=$(basename "$f" .md)
    case "$base" in
      README|SCHEMA|AGENTS) continue ;;
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

def presence_errors:
  [
    (if ($fm | has("status") | not) then "status: required field is missing" else empty end),
    (if ($fm | has("pkg") | not) then "pkg: required field is missing" else empty end),
    (if ($fm.status? // null) == "open" then
       (if ($fm | has("milestone") | not) then "milestone: required on open items but missing" else empty end)
     else empty end),
    (if ($fm.status? // null) == "open" then
       (if ($fm | has("size") | not) then "size: required on open items but missing" else empty end)
     else empty end),
    (if ($fm.status? // null) == "open" then
       (if ($fm | has("size_evidence") | not) then "size_evidence: required on open items but missing" else empty end)
     else empty end)
  ];

def size_evidence_errors:
  if ($fm | has("size_evidence")) and ($fm.size_evidence | type) == "string" then
    ($fm.size_evidence) as $ev |
    if $ev == "no cue in source file" then []
    elif ($body | contains($ev)) then []
    else ["size_evidence is neither \"no cue in source file\" nor a substring of the file's own body"]
    end
  else [] end;

(unknown_errors + type_errors + dangling_errors + milestone_note_errors + closed_by_errors + presence_errors + size_evidence_errors)
| .[]
JQ

# Builds todo/README.md's generated index from one JSON array of open+closed item records (each
# the item's frontmatter plus its slug and its H1 title). Milestone groups are rendered 1-8 in
# ladder order, skipping a rung with no open items; within a group, a deterministic topological
# sort orders a `needs` target above the item that needs it, breaking ties (and picking among
# several ready items) alphabetically by slug so the output is reproducible. Only `needs` edges
# whose target is a member of the *same* group are consulted — an edge crossing groups cannot be
# honoured by a single group's row order and is silently not enforced there. A cycle within a group
# is reported as {error: ...} instead of hanging or dropping items. Closed items follow in one
# trailing section, sorted by slug, each with its closed_by.
read -r -d '' gen_program <<'JQ' || true
def esc_pipe: gsub("\\|"; "\\|");

def linkcell:
  ("[" + (.title|esc_pipe) + "](" + .slug + ".md)") as $base
  | if (.milestone_note != null) then $base + " — " + (.milestone_note|esc_pipe) else $base end;

def pkgcell: (.pkg // []) | join(", ");

def depsOf($nodes; $recmap):
  ( ($recmap[.].needs // []) | map(select( . as $d | ($nodes|index($d)) != null )) );

def toposort($recmap):
  . as $nodes
  | def step($state):
      ($state.remaining) as $rem
      | if ($rem|length) == 0 then $state
        else
          ( [ $rem[] | select( (depsOf($nodes;$recmap) - $state.done | length) == 0 ) ] | sort ) as $ready
          | if ($ready|length) == 0 then $state + {cycle:true}
            else
              ($ready[0]) as $next
              | step({done: ($state.done + [$next]), remaining: ($rem - [$next])})
            end
        end;
    step({done: [], remaining: $nodes});

($records | map(select(.status=="open"))) as $open
| ($records | INDEX(.slug)) as $recmap
| [ range(1;9) as $m
    | ($open | map(select((.milestone // []) | index($m) != null)) ) as $members
    | if ($members|length) == 0 then empty
      else
        ($members | map(.slug)) as $nodes
        | ($nodes | toposort($recmap)) as $sorted
        | if ($sorted.cycle // false) then
            {cycle: {milestone: $m, stuck: $sorted.remaining}}
          else
            { group: { milestone: $m, rows: ($sorted.done | map($recmap[.])) } }
          end
      end
  ] as $groups
| ([$groups[] | select(has("cycle"))]) as $cycles
| if ($cycles|length) > 0 then
    {error: ($cycles | map("milestone \(.cycle.milestone): needs cycle among " + (.cycle.stuck|join(", "))) | join("; "))}
  else
    ( [$groups[] | select(has("group")) | .group] ) as $g
    | ( $g | map(
          "## Milestone \(.milestone)\n\n" +
          "| Item | Size | Packages |\n|---|---|---|\n" +
          ( .rows | map("| " + (.|linkcell) + " | " + (.size // "?") + " | " + (.|pkgcell) + " |") | join("\n") )
        ) | join("\n\n")
    ) as $open_text
    | ( $records | map(select(.status=="closed")) | sort_by(.slug)
        | map("| " + (.|linkcell) + " | " + (.closed_by // "") + " |") | join("\n")
      ) as $closed_rows
    | { text: (
          $open_text + "\n\n## Closed\n\n| Item | Closed by |\n|---|---|\n" + $closed_rows
        )
      }
  end
JQ

no_frontmatter=0
error_count=0

records_file=$(mktemp)
trap 'rm -f "$records_file"' EXIT

shopt -s nullglob
for f in "$dir"/*.md; do
  base=$(basename "$f" .md)
  case "$base" in
    README|SCHEMA|AGENTS) continue ;;
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

  # Record this item for index generation, regardless of the schema errors checked below — a
  # generation attempt is only ever made once error_count is confirmed zero, and by then every
  # recorded item's frontmatter is known to be a valid object.
  title=$(grep -m1 '^# ' "$f" | sed 's/^# //') || title=""
  jq -n --arg slug "$base" --arg title "$title" --argjson fm "$fm_json" \
    '($fm | if type == "object" then . else {} end) as $f | {slug: $slug, title: $title} + $f' \
    >> "$records_file"

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

if [ "$no_frontmatter" -gt 0 ]; then
  error_count=$((error_count + no_frontmatter))
  echo "todo/check.sh: $no_frontmatter file(s) under $dir have no frontmatter yet; add a frontmatter block per todo/SCHEMA.md." >&2
else
  echo "todo/check.sh: $no_frontmatter file(s) under $dir have no frontmatter yet."
fi

# Index generation/drift-checking only applies to a directory with a README.md to regenerate or
# compare against — i.e. the real todo/, not a scratch fixture directory used to test malformed
# frontmatter. Also skipped once schema errors are already known, since a record built from
# rejected frontmatter cannot be trusted.
if [ "$error_count" -eq 0 ] && [ -f "$dir/README.md" ]; then
  marker_line=$(grep -n -F -m1 "$index_marker" "$dir/README.md" | cut -d: -f1 || true)
  if [ -z "$marker_line" ]; then
    echo "todo/check.sh: marker not found in $dir/README.md; cannot check or regenerate the index." >&2
    error_count=$((error_count + 1))
  else
    records_json=$(jq -s '.' "$records_file")
    gen_result=$(jq -n --argjson records "$records_json" "$gen_program")
    gen_error=$(jq -r '.error // empty' <<< "$gen_result")
    if [ -n "$gen_error" ]; then
      echo "todo/check.sh: cannot generate $dir/README.md's index: $gen_error" >&2
      error_count=$((error_count + 1))
    else
      generated_text=$(jq -r '.text' <<< "$gen_result")
      candidate_file=$(mktemp)
      trap 'rm -f "$records_file" "$candidate_file"' EXIT
      { head -n "$marker_line" "$dir/README.md"; printf '\n'; printf '%s\n' "$generated_text"; } \
        > "$candidate_file"

      if [ "$write_index" -eq 1 ]; then
        cp "$candidate_file" "$dir/README.md"
      elif ! diff -q "$candidate_file" "$dir/README.md" >/dev/null 2>&1; then
        echo "todo/check.sh: $dir/README.md's generated index is out of date; run: nix develop -c todo/check.sh --write-index" >&2
        error_count=$((error_count + 1))
      fi
    fi
  fi
elif [ "$write_index" -eq 1 ] && [ ! -f "$dir/README.md" ]; then
  echo "todo/check.sh: --write-index needs $dir/README.md to exist with the marker already in place." >&2
  error_count=$((error_count + 1))
fi

if [ "$error_count" -gt 0 ]; then
  echo "todo/check.sh: $error_count error(s)." >&2
  exit 1
fi

exit 0
