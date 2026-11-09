#!/usr/bin/env bash
# The Day 1 decks (#26), as the facilitator sees them: `build.sh slides` builds
# handouts/refresher.pptx, m1.pptx and m2.pptx. Each holds one Challenge slide
# per card of its session, every numbered demo step's SQL, and speaker notes on
# every slide; the refresher also holds the Fix sheet's banner codes and the
# morning Content id. The committed handouts match a fresh build, and no deck
# shows the repo URL. The design itself gets the pptx skill's visual QA.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }
# shellcheck source=tools/cards.sh
source "$root/tools/cards.sh"

decks=(refresher m1 m2)
id=20261110-2100
if ! (cd "$root" && CONTENT_ID="$id" HANDOUTS_DIR="$tmp/handouts" ./build.sh slides) >"$tmp/build.log" 2>&1; then
  bad "build.sh slides failed:"; sed 's/^/  /' "$tmp/build.log"; exit 1
fi

# xml_text: the text of one slide or notes part, one line per paragraph or line
# break, with the XML entities decoded.
xml_text() {
  perl -0pe 's#<a:br/>|</a:p>#\n#g; s#<[^>]+>##g; s#&lt;#<#g; s#&gt;#>#g; s#&quot;#"#g; s#&apos;#'"'"'#g; s#&amp;#&#g'
}
# slides_of <pptx> <out-dir>: slide N's text in <out-dir>/N.txt, its notes in <out-dir>/N.notes.
slides_of() {
  local pptx="$1" out="$2" n part
  mkdir -p "$out"
  n="$(zipinfo -1 "$pptx" | grep -c '^ppt/slides/slide[0-9]*\.xml$')"
  for ((i = 1; i <= n; i++)); do
    unzip -p "$pptx" "ppt/slides/slide$i.xml" | xml_text >"$out/$i.txt"
    part="$(unzip -p "$pptx" "ppt/slides/_rels/slide$i.xml.rels" | grep -o 'notesSlide[0-9]*\.xml' | head -1)"
    if [ -n "$part" ]; then unzip -p "$pptx" "ppt/notesSlides/$part" | xml_text >"$out/$i.notes"; else : >"$out/$i.notes"; fi
  done
}

for deck in "${decks[@]}"; do
  built="$tmp/handouts/$deck.pptx"
  [ -f "$built" ] || { bad "build.sh slides wrote no $deck.pptx"; continue; }
  s="$tmp/text/$deck"; slides_of "$built" "$s"
  total="$(find "$s" -name '*.txt' | wc -l | tr -d ' ')"
  [ "$total" -gt 0 ] || { bad "$deck.pptx has no slides"; continue; }

  # One Challenge slide per card of this session: its title, time box and output on one slide.
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
    while IFS= read -r line; do
      if grep -qxF -- "$line" <(sed 's/^ *//; s/ *$//' "$s"/*.txt); then :
      else bad "$deck: demo $(basename "$demo") step SQL not on any slide: $line"; fi
    done < <(awk '/^-- [0-9]+[a-z]?\. / { want = 1; next } want && /^[^-]/ && NF { sub(/^ +/, ""); sub(/ +$/, ""); print; want = 0 }' "$demo")
    ok "$deck: checked the steps of demos/$deck/$(basename "$demo")"
  done

  # Speaker notes on every slide.
  bare=""
  for ((i = 1; i <= total; i++)); do
    [ "$(tr -d '[:space:]' <"$s/$i.notes" | wc -c)" -ge 40 ] || bare="$bare $i"
  done
  if [ -z "$bare" ]; then ok "$deck: speaker notes on all $total slides"; else bad "$deck: no speaker notes on slide(s)$bare"; fi
done

# The refresher opens the day: the morning Content id, and the Fix sheet's banner codes.
r="$tmp/text/refresher"
if grep -lqF "Content $id" "$r"/*.txt 2>/dev/null; then ok "refresher: a slide shows Content $id"
else bad "refresher: no slide shows Content $id"; fi
# shellcheck disable=SC2016 # the backticks are Markdown, matched literally
codes="$(grep -oE '^\| `[A-Z][A-Za-z0-9<>-]*`' "$root/cards/setup.md" | tr -d '|` ')"
[ -n "$codes" ] || bad "no banner codes found in the setup card's Fix sheet"
for f in "$r"/*.txt; do
  missing=""
  for c in $codes; do grep -qF -- "$c" "$f" || missing="$missing $c"; done
  [ -z "$missing" ] && { hit="$f"; break; }
done
if [ -n "${hit:-}" ]; then ok "refresher: a Fix sheet slide lists every banner code ($(xargs <<<"$codes"))"
else bad "refresher: no slide lists every banner code ($(xargs <<<"$codes"))"; fi

# The committed handouts are this build: the same slides, text and notes (the
# Content id aside, which each release sets).
dump() {
  local i=1
  while [ -f "$1/$i.txt" ]; do
    echo "== slide $i"; sed -E 's/Content [0-9]{8}-[0-9]{4}/Content <id>/g' "$1/$i.txt" "$1/$i.notes"
    i=$((i + 1))
  done
}
for deck in "${decks[@]}"; do
  committed="$root/handouts/$deck.pptx"
  [ -f "$committed" ] || { bad "handouts/$deck.pptx is not committed"; continue; }
  slides_of "$committed" "$tmp/committed/$deck"
  if diff <(dump "$tmp/text/$deck") <(dump "$tmp/committed/$deck") >"$tmp/diff" 2>&1; then
    ok "handouts/$deck.pptx matches a fresh build"
  else bad "handouts/$deck.pptx is stale (run ./build.sh slides):"; head -20 "$tmp/diff" | sed 's/^/  /'; fi
done

# No repo URL or org/repo name anywhere in a deck before the closing.
leaked=0
for deck in "${decks[@]}"; do
  for pptx in "$tmp/handouts/$deck.pptx" "$root/handouts/$deck.pptx"; do
    [ -f "$pptx" ] || continue
    x="$tmp/unzipped"; rm -rf "$x"; mkdir -p "$x"; (cd "$x" && unzip -q "$pptx")
    if leaks="$(grep -r -l -i -e 'drmayu7' -e 'duckdb_advance_workshop' -e 'duckdb-advance-workshop' -e 'github\.com' "$x")"; then
      bad "$pptx shows the repo URL or name in: $(xargs <<<"${leaks//$x\//}")"; leaked=1
    fi
  done
done
[ "$leaked" = 0 ] && ok "no deck shows the repo URL or name"
exit $fail
