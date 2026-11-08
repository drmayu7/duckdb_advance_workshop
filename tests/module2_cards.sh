#!/usr/bin/env bash
# Module 2 cards (#24), beyond what every card is checked for:
#  * C6's "Start here" cell is C5's macros exactly as C5's solution writes them,
#    and C6's solution creates them too, so C6 works after C5's Checkpoint;
#  * the Self-checks count copies (EXCEPT ALL; a plain EXCEPT compares sets):
#    C6's catches a duplicate the Participant forgot to remove, and the earlier
#    tables that keep the AD01 re-exports (C1, C3, C4) catch an answer that
#    dropped them with DISTINCT.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

# shellcheck source=tools/cards.sh
source tools/cards.sh

c6=cards/c06-dedupe.md
card_block "$c6" macros | sql_cell 1 >"$tmp/card_macros.sql"
if [ ! -s "$tmp/card_macros.sql" ]; then
  bad "$c6: no macros block with a sql cell"
else
  # The C5 solution's macro definitions: from the first CREATE OR REPLACE MACRO
  # to the last statement before "-- Try them."
  awk '/^CREATE OR REPLACE MACRO/ { f = 1 } /^-- Try them\./ { exit } f' solutions/c05-facilities.sql \
    | awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] == "") n--; for (i = 1; i <= n; i++) print l[i] }' >"$tmp/c5_macros.sql"
  if diff -q "$tmp/card_macros.sql" "$tmp/c5_macros.sql" >/dev/null; then
    ok "$c6: the macros cell is C5's solution macros"
  else
    bad "$c6: the macros cell differs from solutions/c05-facilities.sql:"; diff "$tmp/card_macros.sql" "$tmp/c5_macros.sql" | sed 's/^/  /'
  fi
  missing="$(grep -oE '^CREATE OR REPLACE MACRO [a-z_]+' "$tmp/card_macros.sql" | while read -r line; do
               grep -qF "$line" solutions/c06-dedupe.sql || echo "${line##* }"; done)"
  if [ -z "$missing" ]; then ok "solutions/c06-dedupe.sql creates C5's macros"
  else bad "solutions/c06-dedupe.sql does not create: $missing"; fi
fi

# A kept duplicate: the expected result plus one copy of one of its rows.
count_cell="$(card_block "$c6" self-check | sql_cell 1)"
n="$("$DUCKDB" -list -noheader "$tmp/work.duckdb" -c "
  CREATE TABLE admission_clean AS FROM 'expected/admission_clean.parquet';
  INSERT INTO admission_clean SELECT * FROM admission_clean LIMIT 1;
  $count_cell" 2>&1)"
if [ "$n" = 1 ]; then ok "$c6: Self-check counts a kept duplicate as 1 row differing"
else bad "$c6: Self-check with one kept duplicate gave '$n', want 1"; fi

for card in cards/c01-read-csv.md cards/c03-combine.md cards/c04-fix-types.md; do
  table="$(card_field "$card" output)"
  count_cell="$(card_block "$card" self-check | sql_cell 1)"
  n="$("$DUCKDB" -list -noheader "$tmp/work.duckdb" -c "
    CREATE OR REPLACE TABLE $table AS SELECT DISTINCT * FROM 'expected/$table.parquet';
    $count_cell" 2>&1)"
  if [ "$n" -gt 0 ] 2>/dev/null; then ok "$card: Self-check catches the re-exported copies dropped by DISTINCT ($n rows differ)"
  else bad "$card: Self-check on a DISTINCT answer gave '$n', want more than 0"; fi
done
exit $fail
