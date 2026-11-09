#!/usr/bin/env bash
# build.sh must refuse any DuckDB other than v1.5.6 (ADR 0002).
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake() { # fake <name> <version line>
  printf '#!/bin/sh\necho "%s"\n' "$2" > "$tmp/$1"
  chmod +x "$tmp/$1"
}

expect_refused() { # expect_refused <label> <duckdb path>
  out="$(DUCKDB="$2" "$root/build.sh" help 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then
    bad "$1: build.sh exited 0"
  elif ! grep -q "v1.5.6" <<<"$out"; then
    bad "$1: message does not name v1.5.6: $out"
  else
    ok "$1 refused"
  fi
}

fake duckdb155 "v1.5.5 (Variegata) 0000000000"
fake duckdb200 "v2.0.0 (Andium) 0000000000"
fake duckdb1560x "v1.5.60 (Fake) 0000000000"
expect_refused "DuckDB 1.5.5" "$tmp/duckdb155"
expect_refused "DuckDB 2.0.0" "$tmp/duckdb200"
expect_refused "DuckDB 1.5.60" "$tmp/duckdb1560x"
expect_refused "missing DuckDB" "$tmp/does-not-exist"

fake duckdb156 "v1.5.6 (Variegata) 069cc9f9b5"
if DUCKDB="$tmp/duckdb156" "$root/build.sh" help >/dev/null 2>&1; then
  ok "DuckDB 1.5.6 accepted"
else
  bad "DuckDB 1.5.6 was refused"
fi
finish
