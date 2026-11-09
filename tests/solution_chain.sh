#!/usr/bin/env bash
# The solution chain (#16 Seam 1): from a fresh Work database at a bundle root,
# run each Challenge's solution in chain order, then the card's own Self-check
# cells. 0 rows differ means a Participant with the right answer sees "done".
# The Self-check must also catch a wrong answer (a missing, changed or extra
# row), and the card's Checkpoint must bring it back to 0. Finally, the
# committed expected/ is what `build.sh expected` writes today, and writing it
# leaves the repo's working tree untouched.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

# shellcheck source=tools/cards.sh
source "$root/tools/cards.sh"

# A bundle root: the content a Participant has, and a fresh Work database.
bundle="$tmp/duckdb-bundle"
mkdir -p "$bundle/data"
cp -R "$root/cards" "$root/solutions" "$root/expected" "$bundle/"
cp -R "$root/data/warmup" "$bundle/data/warmup"
cp -R "$root/data/raw" "$bundle/data/raw"
ln -s "$root/data/open" "$bundle/data/open"
cd "$bundle" || exit 1
work=my_work.duckdb

sql() { "$DUCKDB" -list -noheader "$work" -c "$1" 2>&1; }

while read -r card <&3; do
  base="$(basename "$card" .md)"; table="$(card_field "$card" output)"
  count_cell="$(card_block "$card" self-check | sql_cell 1)"
  rows_cell="$(card_block "$card" self-check | sql_cell 2)"
  checkpoint="$(card_block "$card" checkpoint | sql_cell 1)"

  if ! out="$( { echo .bail on; cat "solutions/$base.sql"; } | "$DUCKDB" "$work" 2>&1 >/dev/null)"; then
    bad "$base: solution failed: $out"; continue
  fi
  n="$(sql "$count_cell")"
  if [ "$n" = 0 ]; then ok "$base: Self-check gives 0 rows differ after the solution"; else bad "$base: Self-check after the solution gave '$n', want 0"; fi
  rows="$(sql "$rows_cell")"
  if [ -z "$rows" ]; then ok "$base: Self-check lists no differing rows"; else bad "$base: Self-check listed rows: $rows"; fi

  # A wrong answer: one row missing and one row changed.
  # The changed column is the first number, or else the first text column.
  num="$(sql "SELECT name FROM pragma_table_info('$table') WHERE type IN ('BIGINT', 'INTEGER', 'DOUBLE') ORDER BY cid LIMIT 1")"
  if [ -n "$num" ]; then change="$num = $num + 1"
  else txt="$(sql "SELECT name FROM pragma_table_info('$table') WHERE type = 'VARCHAR' ORDER BY cid LIMIT 1")"
       change="$txt = coalesce($txt, '') || 'x'"; fi
  sql "DELETE FROM $table WHERE rowid = (SELECT min(rowid) FROM $table);
       UPDATE $table SET $change WHERE rowid = (SELECT max(rowid) FROM $table);" >/dev/null
  n="$(sql "$count_cell")"
  if [ "$n" = 3 ]; then ok "$base: Self-check counts 3 rows differ for a missing row and a changed row"; else bad "$base: Self-check on a wrong answer gave '$n', want 3"; fi
  rows="$(sql "$rows_cell" | cut -d'|' -f1 | sort | uniq -c | awk '{ printf "%s %s;", $1, $2 }')"
  if [ "$rows" = "2 expected;1 yours;" ]; then ok "$base: Self-check shows which side each differing row is on"; else bad "$base: Self-check rows by side were '$rows', want 2 expected, 1 yours"; fi

  # The Checkpoint replaces the wrong answer with the expected result.
  sql "$checkpoint" >/dev/null
  n="$(sql "$count_cell")"
  if [ "$n" = 0 ]; then ok "$base: Checkpoint brings the Self-check back to 0"; else bad "$base: Self-check after the Checkpoint gave '$n', want 0"; fi

  # A kept or extra copy of a row is a wrong answer too, so the Self-check
  # compares copies (EXCEPT ALL), not sets. Then the Checkpoint again.
  sql "INSERT INTO $table SELECT * FROM $table LIMIT 1;" >/dev/null
  n="$(sql "$count_cell")"
  if [ "$n" = 1 ]; then ok "$base: Self-check counts an extra copy of a row as 1 row differing"; else bad "$base: Self-check with an extra copy of a row gave '$n', want 1"; fi
  sql "$checkpoint" >/dev/null
done 3< <(challenge_cards)

# Catching up: a Participant who loaded every earlier Checkpoint, in a fresh
# Work database, runs the next solution and also sees 0 rows differ. An
# Extension track (t-*) gets only the Warm-up and C1-C10 Checkpoints, never
# another track's, so any two tracks can be done in either order (#30).
checkpoints=""
tracks=0
while read -r card <&3; do
  base="$(basename "$card" .md)"
  count_cell="$(card_block "$card" self-check | sql_cell 1)"
  case "$base" in t-*) track=1; tracks=$((tracks + 1)); from="the Warm-up and C1-C10 Checkpoints alone" ;;
                  *)   track=0; from="only the earlier Checkpoints" ;; esac
  if [ -n "$checkpoints" ]; then
    rm -f catchup.duckdb
    if ! out="$( { echo .bail on; echo "$checkpoints"; cat "solutions/$base.sql"; } | "$DUCKDB" catchup.duckdb 2>&1 >/dev/null)"; then
      bad "$base: solution failed after $from: $out"
    else
      n="$("$DUCKDB" -list -noheader catchup.duckdb -c "$count_cell" 2>&1)"
      if [ "$n" = 0 ]; then ok "$base: 0 rows differ from a fresh Work database with $from"
      else bad "$base: from $from the Self-check gave '$n', want 0"; fi
    fi
  fi
  [ "$track" = 1 ] && continue
  checkpoints="$checkpoints
$(card_block "$card" checkpoint | sql_cell 1)"
done 3< <(challenge_cards)
[ "$tracks" -gt 0 ] || bad "no Extension track cards (cards/t-*.md) in the chain"

# expected/ in the repo is current, and building it writes nothing into the
# repo: solutions run in a scratch folder, so a COPY TO (C10's export) lands
# there, not in the repo root.
cd "$root" || exit 1
before="$(git status --porcelain --untracked-files=all)"
if OUT_DIR="$tmp/fresh" ./build.sh expected >"$tmp/expected.log" 2>&1; then
  after="$(git status --porcelain --untracked-files=all)"
  if [ "$before" = "$after" ]; then ok "build.sh expected leaves the repo's working tree as it was"
  else bad "build.sh expected changed the repo's working tree:"; diff <(echo "$before") <(echo "$after") | sed 's/^/  /'; fi
  for f in expected/*.parquet; do
    cmp -s "$f" "$tmp/fresh/$f" || bad "committed $f differs from what build.sh expected writes (rebuild it)"
  done
  for f in "$tmp"/fresh/expected/*.parquet; do
    [ -e "expected/$(basename "$f")" ] || bad "build.sh expected writes $(basename "$f"), which is not committed"
  done
  [ "$fail" = 0 ] && ok "committed expected/ matches build.sh expected"
else
  bad "build.sh expected failed:"; sed 's/^/  /' "$tmp/expected.log"
fi
exit $fail
