#!/usr/bin/env bash
# Module 2 cards (#24), beyond what every card is checked for: C6's "Start
# here" cell is C5's macros exactly as C5's solution writes them, and C6's
# solution creates them too, so C6 works after C5's Checkpoint.
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

exit $fail
