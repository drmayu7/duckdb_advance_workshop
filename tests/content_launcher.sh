#!/usr/bin/env bash
# Applying a Content release, as a Participant does it (#22).
# Seam 2: a Setup release extract, with Content release zips dropped unopened into
# updates/, run through the Mac launcher in check-only mode. The launcher applies
# them, moves them to updates/applied/, and the banner reports the Content id, C1
# and U1. The Work database is never touched. Windows is checked by hand (#20).
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -sm)" != "Darwin arm64" ]; then
  echo "SKIP: the launcher test runs on an Apple Silicon Mac only"; exit 0
fi
tmp="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked by the EXIT trap
cleanup() { chmod -R u+w "$tmp" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT
# shellcheck source=tests/lib/worktree_ref.sh
source "$root/tests/lib/worktree_ref.sh"
ref="$(worktree_ref "$root")" || { bad "could not snapshot the working tree"; finish; }

N=16 # the Setup release's 15 checks (V1, nine E-<ext>, D1, W1, W2, F1, U1) and C1
day1=20261110-2100
day2=20261111-0700

run_or_die() { # run_or_die <log> <cmd...>
  local log="$1"; shift
  if ! "$@" >"$tmp/$log" 2>&1; then bad "$* failed:"; sed 's/^/  /' "$tmp/$log"; finish; fi
}
run_or_die setup.log env DIST_DIR="$tmp/dist" BUNDLE_DATE=20261109 "$root/build.sh" setup
run_or_die day1.log env DIST_DIR="$tmp/dist" CONTENT_REF="$ref" CONTENT_ID=$day1 "$root/build.sh" content
# One tree, two ids: its decks show only Day 1's, so the deck id check is off for Day 2.
run_or_die day2.log env CONTENT_DECK_ID_CHECK=off DIST_DIR="$tmp/dist" CONTENT_REF="$ref" CONTENT_ID=$day2 "$root/build.sh" content
pristine="$tmp/pristine"
mkdir -p "$pristine" && ditto -x -k "$tmp/dist/duckdb-bundle-20261109.zip" "$pristine"

fresh() { # fresh <scenario> -> sets $b (bundle) and $h (home); a clean Setup extract
  b="$tmp/$1/duckdb-bundle"; h="$tmp/$1/home"
  mkdir -p "$(dirname "$b")" "$h" && cp -cR "$pristine" "$b"
}
drop() { cp "$tmp/dist/duckdb-content-$1.zip" "$b/updates/"; } # drop <id>
launch() { # check-only, as a double-click would; sets $banner, $rc
  local out
  out="$(cd "$h" && HOME="$h" TMPDIR="$h" WORKSHOP_CHECK_ONLY=1 "$b/start-workshop.command" </dev/null 2>&1)"; rc=$?
  banner="$(grep '^SETUP ' <<<"$out")"
}
expect_ok() { # expect_ok <label> <content id>
  if [ "$banner" = "SETUP OK ($N/$N) · Content $2" ] && [ "$rc" = 0 ]; then ok "$1: $banner"
  else bad "$1: wanted SETUP OK ($N/$N) · Content $2, got exit $rc, banner: ${banner:-<none>}"; fi
}
expect_failed() { # expect_failed <label> <codes> <content id> [n]
  local n="${4:-$N}" got
  got="$(sed -n "s/^SETUP FAILED ([0-9]*\/$n): \(.*\) · Content $3\$/\1/p" <<<"$banner" | tr ';' '\n' | awk '{print $1}' | sort | xargs)"
  if [ "$got" = "$2" ] && [ "$rc" = 1 ]; then ok "$1: $2 · Content $3"
  else bad "$1: wanted $2 (of $n) · Content $3, got exit $rc, banner: ${banner:-<none>}"; fi
}
sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# A Participant's Day 0 bundle with work in it, then Day 1's release dropped in.
fresh apply; launch
if grep -qi 'error' "$b/setup.log"; then bad "a Setup-only launch logs errors:"; sed 's/^/  /' "$b/setup.log"
else ok "a Setup-only launch logs no errors"; fi
"$b/bin/osx_arm64/duckdb" "$b/my_work.duckdb" -c "CREATE TABLE mine AS SELECT 42 AS answer;" >/dev/null
before="$(sha256_of "$b/my_work.duckdb")"
drop $day1; launch
expect_ok "Day 1 release applied" $day1
[ -f "$b/cards/w-warmup.md" ] && [ -f "$b/cards.html" ] || bad "Day 1 release: cards not extracted over the bundle"
if [ -f "$b/updates/applied/duckdb-content-$day1.zip" ] && [ ! -e "$b/updates/duckdb-content-$day1.zip" ]; then
  ok "the zip moved to updates/applied/"; else bad "the zip was not moved to updates/applied/"; fi
[ -f "$b/updates/README.txt" ] || bad "updates/README.txt is gone"
if [ "$(sha256_of "$b/my_work.duckdb")" = "$before" ]; then ok "my_work.duckdb is byte-identical"
else bad "applying the release changed my_work.duckdb"; fi

# Relaunching does not re-apply it: a card deleted afterwards stays deleted, and C1 says so.
rm "$b/cards/c01-read-csv.md"; launch
expect_failed "a release file deleted" "C1" $day1
[ -e "$b/cards/c01-read-csv.md" ] && bad "relaunch re-applied an applied zip"

fresh truncated; drop $day1; launch
: >"$b/data/warmup/patient_2017.parquet"; launch
expect_failed "a release file truncated" "C1" $day1

fresh no-manifest; drop $day1; launch; rm "$b/content_manifest.csv"; launch
expect_failed "content_manifest.csv missing" "C1" $day1

# Two releases (missed a day): applied in name order, the latest wins.
fresh two; drop $day2; drop $day1; launch
expect_ok "two releases at once" $day2
[ "$(find "$b/updates/applied" -name '*.zip' | wc -l | tr -d ' ')" = 2 ] || bad "two releases: not both moved to updates/applied/"

# A corrupt download: U1, and it stays in updates/ for the USB copy to replace.
fresh corrupt; head -c 4000 "$tmp/dist/duckdb-content-$day1.zip" >"$b/updates/duckdb-content-$day1.zip"; launch
expect_failed "a corrupt zip in updates/" "U1" none 15
[ -f "$b/updates/duckdb-content-$day1.zip" ] || bad "the corrupt zip was moved out of updates/"
cp "$tmp/dist/duckdb-content-$day1.zip" "$b/updates/"; launch
expect_ok "the corrupt zip replaced by a good copy" $day1
finish
