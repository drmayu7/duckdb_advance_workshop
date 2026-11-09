#!/usr/bin/env bash
# The Day 2 demos (#32), as the facilitator runs them: each demos/m3/ file runs
# top to bottom in a fresh Work database at the bundle root, on DuckDB 1.5.6,
# without an error. Two need more than the bundle: s3-demo.sql needs the bucket
# (large_dataset.sh runs it on a local large/), and gsheets-export.sql needs a
# Google sign-in in a browser, so the dry run checks it.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

deck=m3
{
  n=0
  for demo in "$root"/demos/"$deck"/*.sql; do
    [ -e "$demo" ] || continue
    name="demos/$deck/$(basename "$demo")"
    case "$name" in demos/m3/s3-demo.sql | demos/m3/gsheets-export.sql) continue ;; esac
    n=$((n + 1))
    bundle="$tmp/$deck-$(basename "$demo" .sql)"
    mkdir -p "$bundle"
    ln -s "$root/data" "$bundle/data"
    ln -s "$root/expected" "$bundle/expected"
    if (cd "$bundle" && { echo ".bail on"; cat "$demo"; } | "${DUCKDB:-duckdb}" demo.duckdb) >"$tmp/out.log" 2>&1; then
      ok "$name runs"
    else
      bad "$name failed:"; sed 's/^/  /' "$tmp/out.log"
    fi
  done
  if [ "$n" -gt 0 ]; then ok "demos/$deck has $n demo(s) that run offline"; else bad "demos/$deck has no demo that runs offline"; fi
}
finish
