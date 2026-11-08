#!/bin/bash
# Double-click to check this Mac, then open the DuckDB UI on my_work.duckdb.
# First time: right-click > Open, or run: xattr -dr com.apple.quarantine ~/duckdb-bundle
#
# It checks offline first and prints one line: SETUP OK, or SETUP FAILED with the
# codes to look up on the Fix sheet. Problems go to setup.log in this folder.
# Check only, without opening the UI:  WORKSHOP_CHECK_ONLY=1 ./start-workshop.command

# Every path on the cards is relative to this folder.
cd "$(dirname "$0")" || exit 1
DUCKDB=./bin/osx_arm64/duckdb

if [ "$(uname -m)" != "arm64" ]; then
  echo "This bundle is for Apple Silicon Macs. On an Intel Mac, see the Fix sheet."
fi

# F1: a synced folder (iCloud Desktop & Documents, OneDrive) can corrupt my_work.duckdb.
WORKSHOP_F1=0
case "$PWD/" in
  */Desktop/*|*/Documents/*|*OneDrive*) WORKSHOP_F1=1 ;;
esac
export WORKSHOP_F1

# setup.log goes next to the bundle, or to the temp folder if this one is read-only.
LOG=setup.log
if ! { : >"$LOG"; } 2>/dev/null; then
  LOG="${TMPDIR:-/tmp}/duckdb-setup.log"
  : >"$LOG"
fi

"$DUCKDB" :memory: -f install.sql >>"$LOG" 2>&1
banner="$("$DUCKDB" :memory: -f smoke_test.sql 2>>"$LOG")"
[ -n "$banner" ] || banner="SETUP FAILED: the setup check could not run, see $LOG"

echo
echo "$banner"
echo

case "$banner" in
  "SETUP OK"*) ok=1 ;;
  *) ok=0 ;;
esac

if [ "${WORKSHOP_CHECK_ONLY:-}" = 1 ]; then
  [ "$ok" = 1 ] && exit 0
  exit 1
fi

if [ "$ok" = 0 ]; then
  read -r -s -n 1 -p "Press any key to open the DuckDB UI anyway..."
  echo
fi

exec "$DUCKDB" -ui my_work.duckdb
