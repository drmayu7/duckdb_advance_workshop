#!/usr/bin/env bash
# The Day 1 decks (#26), as the facilitator sees them: `build.sh slides` builds
# handouts/refresher.pptx, m1.pptx and m2.pptx. Each holds one Challenge slide
# per card of its session, every numbered demo step's SQL, and speaker notes on
# every slide; the refresher also holds the Fix sheet's banner codes and the
# morning Content id. The committed handouts match a fresh build, and no deck
# shows the repo URL. The design itself gets the pptx skill's visual QA.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# shellcheck source=tests/lib/decks.sh
. "$root/tests/lib/decks.sh"

decks=(refresher m1 m2)
id=20261110-2100
build_decks "$id"
for deck in "${decks[@]}"; do check_deck "$deck"; done

# The refresher opens the day: the morning Content id, and the Fix sheet's banner codes.
if slide_with refresher "Content $id" >/dev/null; then ok "refresher: a slide shows Content $id"
else bad "refresher: no slide shows Content $id"; fi
# shellcheck disable=SC2016 # the backticks are Markdown, matched literally
codes="$(grep -oE '^\| `[A-Z][A-Za-z0-9<>-]*`' "$root/cards/setup.md" | tr -d '|` ')"
[ -n "$codes" ] || bad "no banner codes found in the setup card's Fix sheet"
# shellcheck disable=SC2086 # one argument per code
if slide_with refresher $codes >/dev/null; then ok "refresher: a Fix sheet slide lists every banner code ($(xargs <<<"$codes"))"
else bad "refresher: no slide lists every banner code ($(xargs <<<"$codes"))"; fi

check_committed "${decks[@]}"
check_no_repo_url "${decks[@]}"
finish
