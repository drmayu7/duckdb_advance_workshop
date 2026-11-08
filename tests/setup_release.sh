#!/usr/bin/env bash
# The Setup release, as a Participant gets it (#18).
# Seam 1: `build.sh setup` makes a zip with exactly the decided paths and no repo URL.
# Seam 2: the extracted Mac launcher, in check-only mode, prints one banner that
# names every fault. Windows is checked by hand (#20).
# Needs network the first time, to fill .cache/setup/ (see tools/fetch_setup_deps.sh).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -sm)" != "Darwin arm64" ]; then
  echo "SKIP: the launcher test runs on an Apple Silicon Mac only"; exit 0
fi
tmp="$(mktemp -d)"
holder=""
# shellcheck disable=SC2329 # invoked by the EXIT trap
cleanup() {
  [ -n "$holder" ] && kill "$holder" 2>/dev/null
  chmod -R u+w "$tmp" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT
fail=0
bad() { echo "FAIL: $*"; fail=1; }

EXTS="ui httpfs aws spatial excel stats_duck rapidfuzz splink_udfs gsheets"
N=14 # V1, nine E-<ext>, D1, W1, W2, F1

# ---- Seam 1: release contents ----------------------------------------------
if ! DIST_DIR="$tmp/dist" BUNDLE_DATE=20261109 "$root/build.sh" setup >"$tmp/build.log" 2>&1; then
  bad "build.sh setup failed:"; sed 's/^/  /' "$tmp/build.log"; exit 1
fi
zip="$tmp/dist/duckdb-bundle-20261109.zip"
[ -f "$zip" ] || { bad "no $zip"; exit 1; }

{
  printf '%s\n' README.txt install.sql smoke_test.sql start-workshop.bat \
    start-workshop.command updates/README.txt \
    bin/windows_amd64/duckdb.exe bin/osx_arm64/duckdb
  for p in windows_amd64 osx_arm64; do
    for e in $EXTS; do echo "repo/v1.5.6/$p/$e.duckdb_extension.gz"; done
  done
  git -C "$root" ls-files data/open
} | sort >"$tmp/want"
zipinfo -1 "$zip" | grep -v '/$' | sort >"$tmp/got"
if diff -q "$tmp/want" "$tmp/got" >/dev/null; then
  echo "ok: zip has exactly the decided paths"
else
  bad "zip paths differ (< missing, > unexpected):"; diff "$tmp/want" "$tmp/got" | grep '^[<>]' | sed 's/^/  /'
fi

pristine="$tmp/pristine"
mkdir -p "$pristine" && ditto -x -k "$zip" "$pristine"
if [ "$(grep -c $'\r$' "$pristine/start-workshop.bat")" = "$(wc -l <"$pristine/start-workshop.bat" | tr -d ' ')" ]; then
  echo "ok: start-workshop.bat has CRLF line endings"
else
  bad "start-workshop.bat is not CRLF throughout (cmd.exe misreads LF batch files)"
fi
if leaks="$(grep -r -l -i -e 'drmayu7' -e 'duckdb_advance_workshop' -e 'duckdb-advance-workshop' "$pristine")"; then
  bad "repo URL or name found in: $leaks"
else
  echo "ok: no repo URL or name in any file"
fi

# ---- Seam 2: launcher in check-only mode -----------------------------------
# Each scenario gets its own copy of the extract (an APFS clone, so it is instant)
# and its own HOME, so ~/.duckdb is never touched.
fresh() { # fresh <scenario> [parent folder name] -> sets $b (bundle) and $h (home)
  b="$tmp/$1/${2:+$2/}duckdb-bundle"; h="$tmp/$1/home"
  mkdir -p "$(dirname "$b")" "$h" && cp -cR "$pristine" "$b"
}
launch() { # runs the launcher as a double-click would, but check-only; sets $banner, $rc
  local out
  out="$(cd "$h" && HOME="$h" TMPDIR="$h" WORKSHOP_CHECK_ONLY=1 "$b/start-workshop.command" </dev/null 2>&1)"; rc=$?
  banner="$(grep '^SETUP ' <<<"$out")"
}
codes() { # the failing codes in $banner, sorted, space-separated
  sed -n 's/^SETUP FAILED ([0-9]*\/[0-9]*): \(.*\) · Content none$/\1/p' <<<"$banner" \
    | tr ';' '\n' | awk '{print $1}' | sort | xargs
}
expect() { # expect <label> <passed count> <codes>
  local want_codes="$3" want_rc=1
  [ -z "$want_codes" ] && want_rc=0
  if [ -z "$want_codes" ] && [ "$banner" = "SETUP OK ($N/$N) · Content none" ] && [ "$rc" = 0 ]; then
    echo "ok: $1: $banner"
  elif [ -n "$want_codes" ] && [ "$(codes)" = "$want_codes" ] && [ "$rc" = "$want_rc" ] \
       && [[ "$banner" == "SETUP FAILED ($2/$N): "* ]]; then
    echo "ok: $1: $want_codes"
  else
    bad "$1: wanted ${want_codes:-OK} ($2/$N) exit $want_rc, got exit $rc, banner: ${banner:-<none>}"
  fi
}

fresh clean; launch
expect "clean extract" $N ""
if [ -f "$b/setup.log" ]; then echo "ok: errors go to setup.log"; else bad "clean extract: no setup.log"; fi
for e in $EXTS; do
  [ -f "$h/.duckdb/extensions/v1.5.6/osx_arm64/$e.duckdb_extension" ] || bad "clean extract: $e not installed per-user"
done
launch
expect "second launch on the same folder" $N ""

fresh no-spatial; rm "$b/repo/v1.5.6/osx_arm64/spatial.duckdb_extension.gz"; launch
expect "missing extension" 13 "E-spatial"
[ -e "$h/.duckdb/extensions/v1.5.6/osx_arm64/spatial.duckdb_extension" ] \
  && bad "missing extension: spatial was downloaded instead of failing"

fresh wrong-cli; cp "$root/.cache/setup/test/duckdb-v1.5.5" "$b/bin/osx_arm64/duckdb"; launch
expect "wrong CLI (1.5.5)" 4 "$(for e in $EXTS; do printf 'E-%s\n' "$e"; done | sort | xargs) V1"

fresh no-data; rm -rf "$b/data/open"; launch
expect "no data" 13 "D1"

fresh partial-data; rm "$b/data/open/population_state.parquet"; launch
expect "one data file missing" 13 "D1"

fresh no-data-list; rm "$b/data/open/SHA256SUMS"; launch
expect "data/open list missing" 13 "D1"

fresh read-only; launch; chmod -R a-w "$b"; launch
expect "read-only folder" 12 "W1 W2"

fresh locked; launch
"$b/bin/osx_arm64/duckdb" "$b/my_work.duckdb" < <(sleep 60) & holder=$!
sleep 1; launch; kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null; holder=""
expect "work database held by another DuckDB" 13 "W2"

for f in OneDrive Desktop Documents; do
  fresh "synced-$f" "$f"; launch
  expect "folder under $f" 13 "F1"
done

fresh several Documents; rm -rf "$b/data/open"; rm "$b/repo/v1.5.6/osx_arm64/excel.duckdb_extension.gz"; launch
expect "several faults" 11 "D1 E-excel F1"
exit $fail
