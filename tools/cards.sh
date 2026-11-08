#!/usr/bin/env bash
# Shared readers for Challenge cards, sourced by build.sh and tests/.
# A card is Markdown with YAML-like front-matter and <!-- begin x --> blocks.

# challenge_cards: Challenge cards in chain order (Warm-up, C1-C10, tracks).
challenge_cards() {
  local card
  for card in cards/w-*.md cards/c[0-9][0-9]-*.md cards/t-*.md; do
    [ -e "$card" ] && echo "$card"
  done
  return 0
}

# card_field <card> <key>: a front-matter value.
card_field() {
  awk -v k="$2" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
                 NR > 1 { i = index($0, ":"); if (substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^ +/, "", v); print v } }' "$1"
}

# card_block <card> <name>: the text between <!-- begin name --> and <!-- end name -->.
card_block() {
  awk -v b="<!-- begin $2 -->" -v e="<!-- end $2 -->" '$0 == e { f = 0 } f { print } $0 == b { f = 1 }' "$1"
}

# sql_cell [n]: the n-th ```sql cell on stdin, or every cell when n is omitted.
sql_cell() {
  awk -v n="${1:-0}" '/^ *```sql *$/ { c++; if (n == 0 || c == n) f = 1; next } /^ *```/ { f = 0 } f'
}
