#!/usr/bin/env bash
# cards_html.sh <root> <out.html>: every card under <root>/cards/ as one offline
# page (pandoc, CSS embedded, nothing fetched). The setup card comes first, then
# the Challenges in chain order, then any other card. Each card sits in a
# <div id="card-<id>">, so the page can link to it.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$1"; out="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
# shellcheck source=tools/cards.sh
source "$here/cards.sh"
cd "$root"

{
  [ -f cards/setup.md ] && echo cards/setup.md
  challenge_cards
  for card in cards/*.md; do echo "$card"; done
} | awk '!seen[$0]++' | while read -r card; do
  echo "::: {#card-$(card_field "$card" id) .card}"
  # The body without its front-matter.
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm' "$card"
  printf '\n:::\n\n'
done | pandoc --from markdown --to html5 --standalone --embed-resources \
  --toc --toc-depth=1 --css "$here/cards.css" \
  --metadata title="DuckDB Workshop Series 2: cards" \
  --metadata lang=en -o "$out"
