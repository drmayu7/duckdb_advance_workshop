#!/usr/bin/env bash
# The dry run, as the facilitator runs it before publishing a Content release (#27).
# Seam: `build.sh dry-run <setup zip> <content zip> [last card]` extracts the Setup
# release fresh, drops the Content release into updates/, launches check-only, then
# runs every solution up to the last card on the bundle's own DuckDB and the card's
# Self-check. It exits 0 only on SETUP OK with the release's id and 0 rows differ
# for every card.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -sm)" != "Darwin arm64" ]; then
  echo "SKIP: the dry run uses the Mac launcher, on an Apple Silicon Mac only"; exit 0
fi
tmp="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked by the EXIT trap
cleanup() { chmod -R u+w "$tmp" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT
# shellcheck source=tests/lib/worktree_ref.sh
source "$root/tests/lib/worktree_ref.sh"
ref="$(worktree_ref "$root")" || { bad "could not snapshot the working tree"; finish; }

id=20261110-2100
indent() { sed "s/^/  /"; }
run_or_die() { # run_or_die <log> <cmd...>
  local log="$1"; shift
  if ! "$@" >"$tmp/$log" 2>&1; then bad "$* failed:"; sed 's/^/  /' "$tmp/$log"; finish; fi
}
run_or_die setup.log env DIST_DIR="$tmp/dist" BUNDLE_DATE=20261109 "$root/build.sh" setup
run_or_die content.log env DIST_DIR="$tmp/dist" CONTENT_REF="$ref" CONTENT_ID=$id "$root/build.sh" content
setup_zip="$tmp/dist/duckdb-bundle-20261109.zip"; content_zip="$tmp/dist/duckdb-content-$id.zip"

# A good pair: the banner, then 0 rows differ for each card up to C3.
out="$("$root/build.sh" dry-run "$setup_zip" "$content_zip" c03 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then ok "a good pair passes"; else bad "a good pair exited $rc:"; indent <<<"$out"; fi
if grep -q "SETUP OK ([0-9]*/[0-9]*) · Content $id" <<<"$out"; then ok "it reports the banner with the release's id"
else bad "no SETUP OK banner with Content $id in:"; indent <<<"$out"; fi
mark
for card in w-warmup c01-read-csv c02-profile c03-combine; do
  grep -q "^ok   $card -> .*: 0 rows differ" <<<"$out" || bad "no '0 rows differ' line for $card"
done
failed || ok "it runs the chain up to the last card, with 0 rows differ each"
if grep -q "c04-fix-types" <<<"$out"; then bad "it ran past the last card"; else ok "it stops at the last card"; fi

# A broken release: C3's expected result has a row missing. Its manifest size is
# corrected, so the launcher passes and only the Self-check can catch it.
broken="$tmp/broken"; mkdir -p "$broken" && (cd "$broken" && unzip -q "$content_zip")
(cd "$broken" && "$DUCKDB" :memory: -c "COPY (FROM 'expected/admission_raw.parquet' LIMIT (SELECT count(*) - 1 FROM 'expected/admission_raw.parquet')) TO 'short.parquet'" \
  && mv short.parquet expected/admission_raw.parquet \
  && size="$(wc -c <expected/admission_raw.parquet | tr -d ' ')" \
  && sed -i '' "s|^expected/admission_raw.parquet,.*|expected/admission_raw.parquet,$size|" content_manifest.csv \
  && mkdir -p ../broken-dist && zip -q -r -X "../broken-dist/duckdb-content-$id.zip" .)
out="$("$root/build.sh" dry-run "$setup_zip" "$tmp/broken-dist/duckdb-content-$id.zip" c03 2>&1)"; rc=$?
if [ "$rc" = 1 ]; then ok "a broken release fails"; else bad "a broken release exited $rc"; fi
if grep -q "^FAIL c03-combine -> admission_raw: 1 rows differ" <<<"$out"; then ok "it names the card and the count"
else bad "no FAIL line for c03-combine in:"; indent <<<"$out"; fi

# Not a Setup and a Content release: a usage error, not a dry run.
"$root/build.sh" dry-run "$content_zip" >/dev/null 2>&1; rc=$?
if [ "$rc" = 2 ]; then ok "missing arguments are a usage error"; else bad "missing arguments exited $rc, want 2"; fi
finish
