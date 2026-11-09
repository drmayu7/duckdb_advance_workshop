#!/usr/bin/env bash
# The Day 2 decks (#32), as the facilitator sees them: `build.sh slides` builds
# handouts/m3.pptx and m4.pptx. Each holds one Challenge slide per card of its
# session, every numbered demo step's SQL, and speaker notes on every slide.
# Module 3 also opens with the morning Content id, and holds the S3 demo's
# backup slides (demos/m3/s3-demo-backup.json), the private-S3 slide and the
# Python/R overview. Module 4 holds the Capstone kickoff: every Angle with its
# summary table, the rubric's criteria and the Hint card rule, but never a Hint
# card's text. The committed handouts match a fresh build, and no deck shows
# the repo URL. The design itself gets the pptx skill's visual QA.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# shellcheck source=tests/lib/decks.sh
. "$root/tests/lib/decks.sh"

decks=(m3 m4)
id=20261112-0700
build_decks "$id"
for deck in "${decks[@]}"; do check_deck "$deck"; done

# Module 3 opens Day 2: the morning Content id.
if slide_with m3 "Content $id" >/dev/null; then ok "m3: a slide shows Content $id"
else bad "m3: no slide shows Content $id"; fi

# The S3 demo's backup slides: each captured step's bytes fetched and rows,
# on a slide marked Backup.
backup="$root/demos/m3/s3-demo-backup.json"
# backup_lines <step>: the step's fetched figure, then each row's first two values.
backup_lines() {
  "${DUCKDB:-duckdb}" :memory: -list -noheader -c "
    WITH s AS (SELECT json_extract(content, '\$.steps.\"$1\"') AS v FROM read_text('$backup'))
    SELECT v->>'fetched' FROM s WHERE v->>'fetched' IS NOT NULL
    UNION ALL SELECT r->>0 FROM s, unnest(CAST(v->'rows' AS JSON[])) AS t(r)
    UNION ALL SELECT r->>1 FROM s, unnest(CAST(v->'rows' AS JSON[])) AS t(r) WHERE r->>1 IS NOT NULL"
}
# (bash 3.2 on macOS has no mapfile, so the arrays below fill with read loops.)
for step in 1 2 3a 3b 4; do
  want=()
  while IFS= read -r l; do want+=("$l"); done < <(backup_lines "$step")
  if [ "${#want[@]}" -eq 0 ]; then bad "m3: $backup has nothing captured for step $step"; continue; fi
  # Numbers appear on slides with thousands separators.
  shown=()
  for w in "${want[@]}"; do
    if [[ "$w" =~ ^[0-9]{4,}$ ]]; then
      shown+=("$(awk '{ n = $0; s = ""; while (length(n) > 3) { s = "," substr(n, length(n) - 2) s; n = substr(n, 1, length(n) - 3) } print n s }' <<<"$w")")
    else shown+=("$w"); fi
  done
  if slide_with m3 "Backup · step $step" "${shown[@]}" >/dev/null; then ok "m3: a backup slide holds step $step's capture (${#shown[@]} values)"
  else bad "m3: no 'Backup · step $step' slide holds all of: ${shown[*]}"; fi
done

# The private-S3 slide: the recipes the guide's "Reading a private bucket" covers.
if slide_with m3 credential_chain "PROVIDER config" PERSISTENT SCOPE which_secret VALIDATION >/dev/null; then
  ok "m3: a private-S3 slide covers credential_chain, config, PERSISTENT, SCOPE, which_secret and VALIDATION"
else bad "m3: no slide covers credential_chain, PROVIDER config, PERSISTENT, SCOPE, which_secret and VALIDATION"; fi

# The 5 min Python/R overview slide.
if slide_with m3 "DuckDB + Python" "DuckDB + R" "Take-home notebooks" >/dev/null; then ok "m3: a Python/R overview slide"
else bad "m3: no slide with DuckDB + Python, DuckDB + R and the Take-home notebooks"; fi

# The Capstone kickoff: every Angle with its summary table, from the brief.
tables=()
# shellcheck disable=SC2016 # the backticks are Markdown, matched literally
while IFS= read -r l; do tables+=("$l"); done < <(grep -oE '^\| \*\*[A-C]\*\* \|.*`[a-z0-9_]+` \|$' "$root/capstone/brief.md" | grep -oE '`[a-z0-9_]+`' | tr -d '`')
if [ "${#tables[@]}" -eq 3 ]; then
  if slide_with m4 "${tables[@]}" >/dev/null; then ok "m4: a slide holds every Angle's summary table (${tables[*]})"
  else bad "m4: no slide holds every Angle's summary table (${tables[*]})"; fi
else bad "capstone/brief.md: expected 3 Angle rows, found ${#tables[@]}"; fi

# The rubric's four criteria, from the rubric.
criteria=()
while IFS= read -r l; do criteria+=("$l"); done < <(grep -oE '^\| \*\*[^*]+\*\* \|' "$root/capstone/rubric.md" | sed -E 's/^\| \*\*//; s/\*\* \|$//')
if [ "${#criteria[@]}" -eq 4 ]; then
  if slide_with m4 "${criteria[@]}" >/dev/null; then ok "m4: a rubric slide holds the four criteria"
  else bad "m4: no slide holds the rubric's four criteria (${criteria[*]})"; fi
else bad "capstone/rubric.md: expected 4 criteria, found ${#criteria[@]}"; fi

# The Hint card rule, and never a Hint card's text: hints.md is facilitator only.
if slide_with m4 "Hint card" "10.30" >/dev/null; then ok "m4: a slide gives the Hint card rule (10.30)"
else bad "m4: no slide gives the Hint card rule (Hint card, 10.30)"; fi
hints=()
while IFS= read -r l; do hints+=("$l"); done < <(awk '/^## Hint card/ { on = 1; next } on && /^(- )?[A-Z]/ { sub(/^- /, ""); gsub(/\*\*/, ""); print substr($0, 1, 40) }' "$root/capstone/hints.md")
[ "${#hints[@]}" -gt 0 ] || bad "capstone/hints.md: no Hint card lines found"
leaked=""
for deck in "${decks[@]}"; do
  for h in ${hints[@]+"${hints[@]}"}; do
    grep -qF -- "$h" "$tmp/text/$deck"/*.txt "$tmp/text/$deck"/*.notes 2>/dev/null && leaked="$leaked $deck:'$h'"
  done
done
if [ -z "$leaked" ]; then ok "no deck holds a Hint card's text (${#hints[@]} lines checked)"
else bad "a deck holds Hint card text:$leaked"; fi

check_committed "${decks[@]}"
check_no_repo_url "${decks[@]}"
finish
