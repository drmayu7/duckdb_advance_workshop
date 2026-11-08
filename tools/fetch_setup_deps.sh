#!/usr/bin/env bash
# Fills .cache/setup/ with what the Setup release ships but the repo doesn't commit:
# the DuckDB v1.5.6 CLIs and the extension repo for windows_amd64 and osx_arm64.
# It also fetches a v1.5.5 CLI that only the launcher test uses (the V1 fault).
#
# Every file is checked against setup/downloads.lock (sha256, cache path, URL).
# A cached file that matches is not downloaded again, so only the first run needs
# network. To re-pin after changing the lists below: tools/fetch_setup_deps.sh --update-lock
set -euo pipefail
cd "$(dirname "$0")/.."
LOCK=setup/downloads.lock
CACHE=.cache/setup
V=v1.5.6
PLATFORMS="windows_amd64 osx_arm64"
CORE="ui httpfs aws spatial excel"
COMMUNITY="stats_duck rapidfuzz splink_udfs gsheets"
GH=https://github.com/duckdb/duckdb/releases/download

sources() { # <cache path> <url>, one per line
  echo "cli/duckdb_cli-windows-amd64.zip $GH/$V/duckdb_cli-windows-amd64.zip"
  echo "cli/duckdb_cli-osx-arm64.zip $GH/$V/duckdb_cli-osx-arm64.zip"
  echo "test/duckdb_cli-osx-arm64-v1.5.5.zip $GH/v1.5.5/duckdb_cli-osx-arm64.zip"
  local p e
  for p in $PLATFORMS; do
    for e in $CORE; do
      echo "repo/$V/$p/$e.duckdb_extension.gz https://extensions.duckdb.org/$V/$p/$e.duckdb_extension.gz"
    done
    for e in $COMMUNITY; do
      echo "repo/$V/$p/$e.duckdb_extension.gz https://community-extensions.duckdb.org/$V/$p/$e.duckdb_extension.gz"
    done
  done
}

sha() { shasum -a 256 "$1" | awk '{print $1}'; }

download() { # download <cache path> <url>
  mkdir -p "$(dirname "$CACHE/$1")"
  curl -fsSL --retry 3 -o "$CACHE/$1.part" "$2"
  mv "$CACHE/$1.part" "$CACHE/$1"
}

if [ "${1:-}" = "--update-lock" ]; then
  : >"$LOCK.new"
  while read -r path url; do
    echo "fetch: $url" >&2
    download "$path" "$url"
    echo "$(sha "$CACHE/$path") $path $url" >>"$LOCK.new"
  done < <(sources)
  mv "$LOCK.new" "$LOCK"
  echo "fetch: wrote $LOCK" >&2
fi

[ -f "$LOCK" ] || { echo "fetch: $LOCK is missing; run with --update-lock" >&2; exit 1; }
while read -r want path url; do
  if [ ! -f "$CACHE/$path" ] || [ "$(sha "$CACHE/$path")" != "$want" ]; then
    echo "fetch: $url" >&2
    download "$path" "$url"
  fi
  got="$(sha "$CACHE/$path")"
  if [ "$got" != "$want" ]; then
    echo "fetch: $path has sha256 $got, but $LOCK pins $want" >&2
    exit 1
  fi
done <"$LOCK"

# Unpack the CLIs next to the zips (the bundle ships them extracted, #11).
unpack() { # unpack <zip> <member> <dest>
  if [ ! -f "$CACHE/$3" ] || [ "$CACHE/$1" -nt "$CACHE/$3" ]; then
    mkdir -p "$(dirname "$CACHE/$3")"
    unzip -p "$CACHE/$1" "$2" >"$CACHE/$3.part"
    chmod 755 "$CACHE/$3.part"
    mv "$CACHE/$3.part" "$CACHE/$3"
  fi
}
unpack cli/duckdb_cli-windows-amd64.zip duckdb.exe bin/windows_amd64/duckdb.exe
unpack cli/duckdb_cli-osx-arm64.zip duckdb bin/osx_arm64/duckdb
unpack test/duckdb_cli-osx-arm64-v1.5.5.zip duckdb test/duckdb-v1.5.5
