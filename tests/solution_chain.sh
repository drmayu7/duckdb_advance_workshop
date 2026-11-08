#!/usr/bin/env bash
# The solution chain (#16 Seam 1): from a fresh Work database at a bundle root,
# run each Challenge's solution in chain order, then the card's own Self-check
# cells. 0 rows differ means a Participant with the right answer sees "done".
# The Self-check must also catch a wrong answer, and the card's Checkpoint must
# bring it back to 0. Finally, the committed expected/ is what `build.sh expected`
# writes today.
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
  num="$(sql "SELECT name FROM pragma_table_info('$table') WHERE type IN ('BIGINT', 'INTEGER', 'DOUBLE') ORDER BY cid LIMIT 1")"
  sql "DELETE FROM $table WHERE rowid = (SELECT min(rowid) FROM $table);
       UPDATE $table SET $num = $num + 1 WHERE rowid = (SELECT max(rowid) FROM $table);" >/dev/null
  n="$(sql "$count_cell")"
  if [ "$n" = 3 ]; then ok "$base: Self-check counts 3 rows differ for a missing row and a changed row"; else bad "$base: Self-check on a wrong answer gave '$n', want 3"; fi
  rows="$(sql "$rows_cell" | cut -d'|' -f1 | sort | uniq -c | awk '{ printf "%s %s;", $1, $2 }')"
  if [ "$rows" = "2 expected;1 yours;" ]; then ok "$base: Self-check shows which side each differing row is on"; else bad "$base: Self-check rows by side were '$rows', want 2 expected, 1 yours"; fi

  # The Checkpoint replaces the wrong answer with the expected result.
  sql "$checkpoint" >/dev/null
  n="$(sql "$count_cell")"
  if [ "$n" = 0 ]; then ok "$base: Checkpoint brings the Self-check back to 0"; else bad "$base: Self-check after the Checkpoint gave '$n', want 0"; fi
done 3< <(challenge_cards)

# expected/ in the repo is current.
cd "$root" || exit 1
if OUT_DIR="$tmp/fresh" ./build.sh expected >"$tmp/expected.log" 2>&1; then
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
