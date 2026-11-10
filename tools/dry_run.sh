#!/usr/bin/env bash
# dry_run.sh <setup zip> <content zip> [last card]: a Participant's laptop, before
# a Content release is published (#27). Extracts the Setup release into a fresh
# folder with an empty HOME, drops the Content release unopened into updates/,
# launches check-only, then runs each solution in chain order up to the last card
# (an id prefix such as c06; default: every card) on the bundle's own DuckDB and
# the card's Self-check. Exit 0: SETUP OK with the release's id and 0 rows differ
# for every card. Exit 1: any failure, named. Exit 2: usage. Apple Silicon Mac only.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
usage() { echo "usage: build.sh dry-run <duckdb-bundle-*.zip> <duckdb-content-*.zip> [last card, e.g. c06]" >&2; exit 2; }
[ $# -ge 2 ] && [ -f "$1" ] && [ -f "$2" ] || usage
setup_zip="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
content_zip="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
last="${3:-}"
[ "$(uname -sm)" = "Darwin arm64" ] || { echo "dry-run: needs an Apple Silicon Mac (the Mac launcher)" >&2; exit 1; }
id="$(unzip -p "$content_zip" release.txt 2>/dev/null | tr -d '\r\n')"
[ -n "$id" ] || { echo "dry-run: $2 has no release.txt: not a Content release" >&2; exit 1; }

tmp="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked by the EXIT trap
cleanup() { chmod -R u+w "$tmp" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT
bundle="$tmp/duckdb-bundle"; home="$tmp/home"
mkdir -p "$bundle" "$home"
ditto -x -k "$setup_zip" "$bundle" || { echo "dry-run: could not extract $1" >&2; exit 1; }
cp "$content_zip" "$bundle/updates/"

out="$(cd "$home" && HOME="$home" TMPDIR="$home" WORKSHOP_CHECK_ONLY=1 "$bundle/start-workshop.command" </dev/null 2>&1)"
banner="$(grep '^SETUP ' <<<"$out")"
echo "dry-run: ${banner:-no banner}"
if ! [[ "$banner" =~ ^SETUP\ OK\ \(([0-9]+)/([0-9]+)\)\ ·\ Content\ (.*)$ ]] \
   || [ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[2]}" ] || [ "${BASH_REMATCH[3]}" != "$id" ]; then
  echo "dry-run: FAILED: wanted SETUP OK (n/n) · Content $id" >&2; exit 1
fi

cd "$bundle" || exit 1
# shellcheck source=tools/cards.sh
source "$here/cards.sh"
duckdb="$bundle/bin/osx_arm64/duckdb"; work=my_work.duckdb
sql() { HOME="$home" "$duckdb" -list -noheader "$work" -c "$1" 2>&1; }
n=0; failures=0; reached=""
while read -r card <&3; do
  base="$(basename "$card" .md)"; table="$(card_field "$card" output)"; n=$((n + 1))
  if ! err="$( { echo .bail on; cat "solutions/$base.sql"; } | HOME="$home" "$duckdb" "$work" 2>&1 >/dev/null)"; then
    echo "FAIL $base -> $table: solution failed: $err"; failures=$((failures + 1))
  else
    differ="$(sql "$(card_block "$card" self-check | sql_cell 1)")"
    if [ "$differ" = 0 ]; then echo "ok   $base -> $table: 0 rows differ"
    else echo "FAIL $base -> $table: $differ rows differ"; failures=$((failures + 1)); fi
  fi
  if [ -n "$last" ] && [[ "$base" == "$last"* ]]; then reached=1; break; fi
done 3< <(challenge_cards)
if [ "$n" = 0 ]; then echo "dry-run: FAILED: no Challenge cards in the release" >&2; exit 1; fi
if [ -n "$last" ] && [ -z "$reached" ]; then echo "dry-run: FAILED: no card '$last' in the release" >&2; exit 1; fi
if [ "$failures" = 0 ]; then echo "dry-run: OK (Content $id, $n cards)"; else echo "dry-run: FAILED ($failures of $n cards)" >&2; exit 1; fi
