#!/usr/bin/env bash
# The Day 1 demos (#26), as the facilitator runs them: each demos/refresher/,
# demos/m1/ and demos/m2/ file runs top to bottom in a fresh Work database at
# the bundle root, on DuckDB 1.5.6, without an error.
# csv-vs-parquet.sql needs large/ and runs in large_dataset.sh.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

for deck in refresher m1 m2; do
  n=0
  for demo in "$root"/demos/"$deck"/*.sql; do
    [ -e "$demo" ] || continue
    name="demos/$deck/$(basename "$demo")"
    [ "$name" = demos/m1/csv-vs-parquet.sql ] && continue
    n=$((n + 1))
    bundle="$tmp/$deck-$(basename "$demo" .sql)"
    mkdir -p "$bundle"
    ln -s "$root/data" "$bundle/data"
    if (cd "$bundle" && { echo ".bail on"; cat "$demo"; } | "$DUCKDB" demo.duckdb) >"$tmp/out.log" 2>&1; then
      ok "$name runs"
    else
      bad "$name failed:"; sed 's/^/  /' "$tmp/out.log"
    fi
  done
  if [ "$n" -gt 0 ]; then ok "demos/$deck has $n demo(s)"; else bad "demos/$deck has no demo"; fi
done
exit $fail
