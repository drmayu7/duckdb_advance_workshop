#!/usr/bin/env bash
# Module 3 cards (#29), beyond what every card is checked for (its macros cell
# is checked in challenge_cards.sh): C10's export. After its solution (from the
# earlier Checkpoints, in a bundle folder), the card's export check gives 0 and
# 0, the Excel file reads back, and a broken export does not pass.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# shellcheck source=tools/cards.sh
source tools/cards.sh

c10=cards/c10-state-brief.md

# The export, in a bundle folder with a fresh Work database.
bundle="$tmp/duckdb-bundle"
mkdir -p "$bundle"
cp -R expected solutions "$bundle/"
ln -s "$root/data" "$bundle/data"
cd "$bundle" || exit 1
check="$(card_block "$root/$c10" export-check | sql_cell 1)"
[ -n "$check" ] || bad "$c10: no export-check block with a sql cell"

checkpoints="$(for c in c06-dedupe c07-hospital-load c09-readmission; do card_block "$root/cards/$c.md" checkpoint | sql_cell 1; done)"
if ! out="$( { echo .bail on; echo "$checkpoints"; cat solutions/c10-state-brief.sql; } | "$DUCKDB" work.duckdb 2>&1 >/dev/null)"; then
  bad "C10 solution failed after the Checkpoints: $out"
else
  for f in state_brief.parquet state_brief.csv state_brief.xlsx; do
    if [ -f "$f" ]; then ok "C10 writes $f in the bundle folder"; else bad "C10 did not write $f"; fi
  done
  got="$("$DUCKDB" -list -noheader work.duckdb -c "$check" 2>&1)"
  if [ "$got" = "0|0" ]; then ok "$c10: export check gives 0 and 0 after the solution"; else bad "$c10: export check gave '$got', want 0|0"; fi
  got="$("$DUCKDB" -list -noheader work.duckdb -c "LOAD excel; SELECT count(*) FROM read_xlsx('state_brief.xlsx');" 2>&1)"
  if [ "$got" = 16 ]; then ok "state_brief.xlsx reads back with 16 states"; else bad "state_brief.xlsx read back gave '$got', want 16"; fi

  # A broken export: the CSV loses a row, the Parquet is written from a changed table.
  "$DUCKDB" work.duckdb -c "
    COPY (FROM state_brief ORDER BY state LIMIT 15) TO 'state_brief.csv' (HEADER true);
    COPY (SELECT * REPLACE (diabetes_readmit_pct + 1 AS diabetes_readmit_pct) FROM state_brief) TO 'state_brief.parquet' (FORMAT parquet);" >/dev/null
  got="$("$DUCKDB" -list -noheader work.duckdb -c "$check" 2>&1)"
  if [ "$got" = "32|1" ]; then ok "$c10: export check catches a changed Parquet and a short CSV"; else bad "$c10: broken export gave '$got', want 32|1"; fi
fi
finish
