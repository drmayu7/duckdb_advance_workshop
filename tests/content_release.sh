#!/usr/bin/env bash
# The Content release, as the facilitator builds it (#22).
# Seam 1: `build.sh content` makes duckdb-content-<id>.zip from HEAD with exactly
# the decided content paths, a release.txt, a content_manifest.csv that matches
# the zip, a self-contained cards.html, and no repo URL. Applying it on a laptop
# is tested in content_launcher.sh.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# shellcheck source=tests/lib/worktree_ref.sh
source "$root/tests/lib/worktree_ref.sh"
ref="$(worktree_ref "$root")" || { bad "could not snapshot the working tree"; finish; }

id=20261110-2100
if ! DIST_DIR="$tmp/dist" CONTENT_ID="$id" CONTENT_REF="$ref" "$root/build.sh" content >"$tmp/build.log" 2>&1; then
  bad "build.sh content failed:"; sed 's/^/  /' "$tmp/build.log"; finish
fi
zip="$tmp/dist/duckdb-content-$id.zip"
[ -f "$zip" ] || { bad "no $zip"; finish; }

# The morning slide must show the release's own id. Decks built for 20261110-2100
# don't belong in a 20261111-0700 release: the build refuses, naming the deck.
if DIST_DIR="$tmp/dist-other" CONTENT_ID=20261111-0700 CONTENT_REF="$ref" "$root/build.sh" content >"$tmp/other.log" 2>&1; then
  bad "a release whose decks show another Content id was built"
elif grep -q 'handouts/refresher.pptx shows Content 20261110-2100, not 20261111-0700' "$tmp/other.log" \
     && [ ! -e "$tmp/dist-other/duckdb-content-20261111-0700.zip" ]; then
  ok "a release whose decks show another Content id is refused, naming the deck"
else
  bad "the mismatched release failed without naming the deck, or left a zip:"; sed 's/^/  /' "$tmp/other.log"
fi

# The decided content paths, as committed at HEAD, plus the four built files.
{
  git -C "$root" ls-tree -r --name-only "$ref" -- cards solutions expected data/raw \
    data/warmup data/capstone capstone demos handouts | grep -v '^capstone/hints\.md$'
  printf '%s\n' cards.html smoke_test.sql release.txt content_manifest.csv
} | sort >"$tmp/want"
zipinfo -1 "$zip" | grep -v '/$' | sort >"$tmp/got"
if diff -q "$tmp/want" "$tmp/got" >/dev/null; then
  ok "zip has exactly the decided content paths"
else
  bad "zip paths differ (< missing, > unexpected):"; diff "$tmp/want" "$tmp/got" | grep '^[<>]' | sed 's/^/  /'
fi
if grep -q '^cards/w-warmup\.md$' "$tmp/got"; then ok "the Warm-up card is in the release"; else bad "no Warm-up card"; fi

# The Capstone (#31): the brief and the 2021 extract ship; capstone_truth/ and
# the Hint cards exist in the tree it is built from, and stay out.
mark
for f in capstone/brief.md capstone/brief_template.md capstone/rubric.md data/capstone/manifest.csv data/capstone/2021-01-sabah.csv data/capstone/2021-01.parquet; do
  grep -qx "$f" "$tmp/got" || bad "the Capstone file $f is not in the release"
done
failed || ok "the Capstone brief, rubric, template and 2021 extract are in the release"
for f in capstone/hints.md capstone_truth/readmit_2021.parquet capstone_truth/check.sql; do
  [ -n "$(git -C "$root" ls-tree --name-only "$ref" -- "$f")" ] || bad "$f is not in the tree, so its absence proves nothing"
done
if never="$(grep -E '^(bin|repo|generator|capstone_truth)/|^start-workshop\.|^install\.sql$|\.duckdb$|^capstone/hints\.md$|^updates/' "$tmp/got")"; then
  bad "release holds paths it must never hold: $(xargs <<<"$never")"
else
  ok "no bin/, repo/, launchers, install.sql, .duckdb, generator/, capstone_truth/ or hints.md"
fi

extracted="$tmp/extracted"; mkdir -p "$extracted"; (cd "$extracted" && unzip -q "$zip")

got_id="$(tr -d '\r\n' <"$extracted/release.txt")"
if [ "$got_id" = "$id" ]; then ok "release.txt holds the id"; else bad "release.txt holds '$got_id', not '$id'"; fi

# content_manifest.csv: path,size for every other file in the zip, sizes as shipped.
if [ "$(head -1 "$extracted/content_manifest.csv")" = "path,size" ]; then ok "manifest header path,size"
else bad "manifest header is '$(head -1 "$extracted/content_manifest.csv")'"; fi
tail -n +2 "$extracted/content_manifest.csv" | sort >"$tmp/manifest"
(cd "$extracted" && grep -v '^content_manifest\.csv$' "$tmp/got" | while read -r f; do echo "$f,$(wc -c <"$f" | tr -d ' ')"; done) \
  | sort >"$tmp/actual"
if diff -q "$tmp/manifest" "$tmp/actual" >/dev/null; then ok "content_manifest.csv matches the zip"
else bad "content_manifest.csv differs from the zip:"; diff "$tmp/manifest" "$tmp/actual" | grep '^[<>]' | head | sed 's/^/  /'; fi

# No repo URL before the 13 Nov reveal, in any file. A deck or document is a zip
# whose XML is compressed, so grep sees into it only once it is unzipped.
unpacked="$tmp/unpacked"; mkdir -p "$unpacked"
n=0
while IFS= read -r -d '' doc; do
  n=$((n + 1)); mkdir -p "$unpacked/${doc#"$extracted"/}"; unzip -q "$doc" -d "$unpacked/${doc#"$extracted"/}"
done < <(find "$extracted" \( -name '*.pptx' -o -name '*.docx' -o -name '*.xlsx' \) -print0)
if [ "$n" -gt 0 ]; then ok "looked inside $n deck(s) and document(s)"; else bad "no deck in the release to look inside"; fi
if leaks="$(grep -r -l -i -e 'drmayu7' -e 'duckdb_advance_workshop' -e 'duckdb-advance-workshop' -e 'github\.com' "$extracted" "$unpacked")"; then
  bad "repo URL or name found in: $(xargs <<<"${leaks//$tmp\//}")"
else
  ok "no repo URL or name in any file, decks included"
fi

# cards.html: one offline page holding every card, with nothing fetched from the network.
mark
for card in "$extracted"/cards/*.md; do
  cid="$(awk -F': *' 'NR > 1 && $1 == "id" { print $2; exit }' "$card")"
  grep -q "id=\"card-$cid\"" "$extracted/cards.html" || bad "cards.html has no card '$cid'"
done
failed || ok "cards.html holds every card"
if ext="$(grep -Eo '(src|href)="(https?:)?//[^"]*"' "$extracted/cards.html")"; then
  bad "cards.html loads from the network: $(xargs <<<"$ext")"
else
  ok "cards.html loads nothing from the network"
fi
if grep -q '<style' "$extracted/cards.html"; then ok "cards.html carries its own style"; else bad "cards.html has no inline style"; fi
finish
