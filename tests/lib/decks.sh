#!/usr/bin/env bash
# Deck checks shared by the deck tests (#26, #32). Source after check.sh, with
# $root (the repo) and $tmp (a scratch folder) set:
#
#   build_decks <content-id>       ./build.sh slides into $tmp/handouts, text in $tmp/text/<deck>/
#   check_deck <deck>              one Challenge slide per card, demo steps, notes on every slide
#   check_committed <deck...>      handouts/<deck>.pptx matches the fresh build
#   check_no_repo_url <deck...>    no deck shows the repo URL or name
#
# Slide N's text is in $tmp/text/<deck>/N.txt and its notes in N.notes.
: "${root:?decks.sh needs root}" "${tmp:?decks.sh needs tmp}"

# shellcheck source=tools/cards.sh
source "$root/tools/cards.sh"

# xml_text: the text of one slide or notes part, one line per paragraph or line
# break, with the XML entities decoded.
xml_text() {
  perl -0pe 's#<a:br/>|</a:p>#\n#g; s#<[^>]+>##g; s#&lt;#<#g; s#&gt;#>#g; s#&quot;#"#g; s#&apos;#'"'"'#g; s#&amp;#&#g'
}

# slides_of <pptx> <out-dir>: slide N's text in <out-dir>/N.txt, its notes in <out-dir>/N.notes.
slides_of() {
  local pptx="$1" out="$2" n i part
  mkdir -p "$out"
  n="$(zipinfo -1 "$pptx" | grep -c '^ppt/slides/slide[0-9]*\.xml$')"
  for ((i = 1; i <= n; i++)); do
    unzip -p "$pptx" "ppt/slides/slide$i.xml" | xml_text >"$out/$i.txt"
    part="$(unzip -p "$pptx" "ppt/slides/_rels/slide$i.xml.rels" | grep -o 'notesSlide[0-9]*\.xml' | head -1)"
    if [ -n "$part" ]; then unzip -p "$pptx" "ppt/notesSlides/$part" | xml_text >"$out/$i.notes"; else : >"$out/$i.notes"; fi
  done
}

build_decks() {
  if ! (cd "$root" && CONTENT_ID="$1" HANDOUTS_DIR="$tmp/handouts" ./build.sh slides) >"$tmp/build.log" 2>&1; then
    bad "build.sh slides failed:"; sed 's/^/  /' "$tmp/build.log"; finish
  fi
}

# slide_count <deck>: the slides of the fresh build (0 if it wrote no deck).
slide_count() {
  find "$tmp/text/$1" -name '*.txt' 2>/dev/null | wc -l | tr -d ' '
}

check_deck() {
  local deck="$1" built="$tmp/handouts/$1.pptx" s="$tmp/text/$1" total card title box out n f demo line bare i
  [ -f "$built" ] || { bad "build.sh slides wrote no $deck.pptx"; return; }
  slides_of "$built" "$s"
  total="$(slide_count "$deck")"
  [ "$total" -gt 0 ] || { bad "$deck.pptx has no slides"; return; }

  # One Challenge slide per card of this session: its title, time box and output on one slide.
  n=0
  while read -r card <&3; do
    [ "$(card_field "$card" module)" = "$deck" ] || continue
    title="$(card_field "$card" title)"; box="$(card_field "$card" timebox)"; out="$(card_field "$card" output)"
    n=0
    for f in "$s"/*.txt; do
      if grep -qF -- "$title" "$f" && grep -qF -- "$box" "$f" && grep -qF -- "$out" "$f"; then n=$((n + 1)); fi
    done
    if [ "$n" = 1 ]; then ok "$deck: one Challenge slide for $(card_field "$card" id) ($title)"
    else bad "$deck: $n Challenge slides for $(card_field "$card" id) ($title), not 1"; fi
  done 3< <(cd "$root" && challenge_cards)

  # Every numbered demo step (-- N. ...) shows its first line of SQL.
  for demo in "$root"/demos/"$deck"/*.sql; do
    [ -e "$demo" ] || continue
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      if grep -qxF -- "$line" <(sed 's/^ *//; s/ *$//' "$s"/*.txt); then :
      else bad "$deck: demo $(basename "$demo") step SQL not on any slide: $line"; fi
    done < <(awk '/^-- [0-9]+[a-z]?\. / { want = 1; next } want && /^[^-]/ && NF { sub(/^ +/, ""); sub(/ +$/, ""); print; want = 0 }' "$demo")
    if [ "$n" -gt 0 ]; then ok "$deck: checked the $n steps of demos/$deck/$(basename "$demo")"
    else bad "$deck: demos/$deck/$(basename "$demo") has no numbered steps"; fi
  done

  # Speaker notes on every slide.
  bare=""
  for ((i = 1; i <= total; i++)); do
    [ "$(tr -d '[:space:]' <"$s/$i.notes" | wc -c)" -ge 40 ] || bare="$bare $i"
  done
  if [ -z "$bare" ]; then ok "$deck: speaker notes on all $total slides"; else bad "$deck: no speaker notes on slide(s)$bare"; fi
}

# slide_with <deck> <text...>: the first slide of the fresh build holding every
# text (fixed strings), or nothing.
slide_with() {
  local deck="$1" f t; shift
  for f in "$tmp/text/$deck"/*.txt; do
    [ -e "$f" ] || continue
    for t in "$@"; do grep -qF -- "$t" "$f" || continue 2; done
    echo "$f"; return 0
  done
  return 1
}

# The committed handouts are this build: the same slides, text and notes (the
# Content id aside, which each release sets).
dump_deck() {
  local i=1
  while [ -f "$1/$i.txt" ]; do
    echo "== slide $i"; sed -E 's/Content [0-9]{8}-[0-9]{4}/Content <id>/g' "$1/$i.txt" "$1/$i.notes"
    i=$((i + 1))
  done
}
check_committed() {
  local deck committed
  for deck in "$@"; do
    committed="$root/handouts/$deck.pptx"
    [ -f "$committed" ] || { bad "handouts/$deck.pptx is not committed"; continue; }
    slides_of "$committed" "$tmp/committed/$deck"
    if diff <(dump_deck "$tmp/text/$deck") <(dump_deck "$tmp/committed/$deck") >"$tmp/diff" 2>&1; then
      ok "handouts/$deck.pptx matches a fresh build"
    else bad "handouts/$deck.pptx is stale (run ./build.sh slides):"; head -20 "$tmp/diff" | sed 's/^/  /'; fi
  done
}

# No repo URL or org/repo name anywhere in a deck before the closing.
check_no_repo_url() {
  local deck pptx x leaks leaked=0
  for deck in "$@"; do
    for pptx in "$tmp/handouts/$deck.pptx" "$root/handouts/$deck.pptx"; do
      [ -f "$pptx" ] || continue
      x="$tmp/unzipped"; rm -rf "$x"; mkdir -p "$x"; (cd "$x" && unzip -q "$pptx")
      if leaks="$(grep -r -l -i -e 'drmayu7' -e 'duckdb_advance_workshop' -e 'duckdb-advance-workshop' -e 'github\.com' "$x")"; then
        bad "$pptx shows the repo URL or name in: $(xargs <<<"${leaks//$x\//}")"; leaked=1
      fi
    done
  done
  [ "$leaked" = 0 ] && ok "no deck of $* shows the repo URL or name"
}
