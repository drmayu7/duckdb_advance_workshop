#!/usr/bin/env bash
# Challenge cards follow the card format (#5, #16): front-matter, the sections a
# Participant works through, an example row that really is in the expected
# result, the exact Checkpoint line, C5's macros on any card that carries them,
# and Series 1 SQL only on the Warm-up.
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

# shellcheck source=tools/cards.sh
source tools/cards.sh

# Every card, including the setup card, has the six front-matter keys.
for card in cards/*.md; do
  for key in id title module timebox input output; do
    [ -n "$(card_field "$card" "$key")" ] || bad "$card: front-matter has no '$key'"
  done
done
[ "$fail" = 0 ] && ok "every card has id, title, module, timebox, input, output"

# A card that uses C5's macros carries them in a "Start here" macros cell, so it
# works after C5's Checkpoint: the cell is C5's solution macros exactly (from the
# first CREATE OR REPLACE MACRO to "-- Try them."), and the card's own solution
# creates them too, so the Reveal also runs after the Checkpoint.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
awk '/^CREATE OR REPLACE MACRO/ { f = 1 } /^-- Try them\./ { exit } f' solutions/c05-facilities.sql \
  | awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] == "") n--; for (i = 1; i <= n; i++) print l[i] }' >"$tmp/c5_macros.sql"

challenges=0
while read -r card <&3; do
  challenges=$((challenges + 1))
  base="$(basename "$card" .md)"; id="$(card_field "$card" id)"; out="$(card_field "$card" output)"
  expected="expected/$out.parquet"

  case "$base" in "$id"-*) ok "$card: file name starts with its id '$id'" ;;
    *) bad "$card: file name does not start with its id '$id'" ;; esac
  if [ -f "solutions/$base.sql" ]; then ok "$card: solution solutions/$base.sql exists"; else bad "$card: no solution solutions/$base.sql"; fi
  if [ -f "$expected" ]; then ok "$card: output '$out' has $expected"; else bad "$card: no $expected for output '$out'"; fi

  if grep -qF '> **Synthetic data, not real hospital performance.**' "$card"; then
    ok "$card: synthetic-data banner"; else bad "$card: no synthetic-data banner"; fi
  for h in 'Definitions' 'Example row' 'Core and Stretch' 'Self-check' 'Checkpoint' 'Reveal'; do
    grep -qE "^## $h\$" "$card" || bad "$card: no '## $h' section"
  done
  awk '/^## Definitions$/ { f = 1; next } /^## / { f = 0 } f' "$card" | grep -qi 'tie-break' \
    || bad "$card: Definitions do not state a tie-break"
  if ! grep -qE '^\| *Core *\|' "$card" || ! grep -qE '^\| *S1 *\|' "$card"; then
    bad "$card: Core and Stretch table needs Core and S1 rows"; fi

  # The Checkpoint is exactly the one line that loads the expected result.
  want="CREATE OR REPLACE TABLE $out AS FROM '$expected';"
  got="$(card_block "$card" checkpoint | sql_cell | sed -E 's/^ +//')"
  if [ "$got" = "$want" ]; then ok "$card: Checkpoint line"; else bad "$card: Checkpoint should be '$want', got '$got'"; fi

  # Self-check: a count of differing rows, then the rows, both against $expected.
  n="$(card_block "$card" self-check | sql_cell | grep -c "'$expected'")"
  if [ "$n" -ge 4 ]; then ok "$card: Self-check compares both ways against $expected"; else bad "$card: Self-check should name '$expected' in both queries, both ways"; fi

  # The example row: its header is the output columns in order, and it is a real
  # row. A cell written NULL matches a NULL value.
  table="$(card_block "$card" example-row | grep -E '^\|')"
  header="$(sed -n 1p <<<"$table" | tr -d ' ' | sed -E 's/^\||\|$//g; s/`//g; s/\|/,/g')"
  row="$(sed -n 3p <<<"$table")"
  if [ -f "$expected" ]; then
    cols="$("$DUCKDB" -list -noheader :memory: -c "SELECT string_agg(name, ',') FROM parquet_schema('$expected') WHERE name <> 'duckdb_schema';")"
    if [ "$header" = "$cols" ]; then ok "$card: example row lists the output columns in order"; else bad "$card: example row columns '$header' are not the output columns '$cols'"; fi
    where="$(awk -F'|' -v cols="$header" 'BEGIN { n = split(cols, c, ",") }
      { for (i = 1; i <= n; i++) { v = $(i + 1); gsub(/^ +| +$|`/, "", v); gsub(/'\''/, "'\'''\''", v)
          printf "%s", (i > 1 ? " AND " : "")
          if (v == "NULL") printf "%s IS NULL", c[i]; else printf "%s::VARCHAR = '\''%s'\''", c[i], v } }' <<<"$row")"
    hits="$("$DUCKDB" -csv -noheader :memory: -c "SELECT count(*) FROM '$expected' WHERE $where;" 2>&1)"
    if [ "$hits" = 1 ]; then ok "$card: example row is a row of $expected"; else bad "$card: example row is not in $expected ($hits): $row"; fi
  fi

  if grep -qF '<!-- begin macros -->' "$card"; then
    card_block "$card" macros | sql_cell 1 >"$tmp/card_macros.sql"
    if [ -s "$tmp/c5_macros.sql" ] && diff -q "$tmp/card_macros.sql" "$tmp/c5_macros.sql" >/dev/null; then
      ok "$card: the macros cell is C5's solution macros"
    else
      bad "$card: the macros cell differs from solutions/c05-facilities.sql:"; diff "$tmp/card_macros.sql" "$tmp/c5_macros.sql" | sed 's/^/  /'
    fi
    missing="$(grep -oE '^CREATE OR REPLACE MACRO [a-z_]+' "$tmp/c5_macros.sql" | while read -r line; do
                 grep -qF "$line" "solutions/$base.sql" || echo "${line##* }"; done)"
    if [ -z "$missing" ]; then ok "solutions/$base.sql creates C5's macros"
    else bad "solutions/$base.sql does not create C5's macros: $missing"; fi
  fi

  # The Warm-up is Series 1 SQL only: nothing Series 2 teaches.
  if [ "$(card_field "$card" module)" = refresher ]; then
    series2='\b(OVER|QUALIFY|WINDOW|PIVOT|UNPIVOT|MACRO|ASOF|LAMBDA|UNNEST|COLUMNS|EXCLUDE|STRUCT|list_[a-z_]+|regexp_[a-z_]+|string_split|read_csv|read_json|COPY|ATTACH)\b'
    used="$( { sql_cell <"$card"; cat "solutions/$base.sql"; } | grep -v '^ *--' \
             | grep -oiE "$series2" | sort -u | tr '\n' ' ')"
    if [ -z "$used" ]; then ok "$card: card and solution use Series 1 SQL only"; else bad "$card: card or solution uses Series 2 SQL: $used"; fi
  fi
done 3< <(challenge_cards)
[ "$challenges" -gt 0 ] || bad "no Challenge cards (cards/w-*.md, cards/cNN-*.md, cards/t-*.md)"
exit $fail
