#!/usr/bin/env bash
# Single entry point for building the Series 2 materials.
# Runs only on DuckDB v1.5.6 (ADR 0002). Override the binary with DUCKDB=/path/to/duckdb.
set -euo pipefail

cd "$(dirname "$0")"
DUCKDB="${DUCKDB:-duckdb}"
REQUIRED_DUCKDB="v1.5.6"
export DUCKDB

usage() {
  cat <<EOF
Usage: ./build.sh <target>

Targets:
  test        Run every check in tests/ and report pass/fail
  open-data   Re-download the frozen open data into data/open/ (needs network)
  help        Show this message
EOF
}

require_duckdb() {
  local found=""
  if command -v "$DUCKDB" >/dev/null 2>&1; then
    found="$("$DUCKDB" --version 2>/dev/null | awk '{print $1}')" || found=""
  fi
  if [ "$found" != "$REQUIRED_DUCKDB" ]; then
    echo "build.sh: DuckDB $REQUIRED_DUCKDB is required, but '$DUCKDB' is ${found:-not runnable}." >&2
    echo "build.sh: install the official $REQUIRED_DUCKDB CLI, or set DUCKDB=/path/to/duckdb-1.5.6." >&2
    exit 1
  fi
}

# test: every tests/*.sql runs in a fresh in-memory DuckDB from the repo root,
# after tests/lib/assert.sql; it passes if DuckDB exits 0. Every tests/*.sh
# runs with DUCKDB exported; it passes if it exits 0. Later tickets add files.
run_tests() {
  local log passed=0 failed=0 t name
  log="$(mktemp)"
  trap 'rm -f "$log"' RETURN

  for t in tests/*.sql tests/*.sh; do
    [ -e "$t" ] || continue
    name="${t#tests/}"
    if case "$t" in
         *.sql) cat tests/lib/assert.sql "$t" | "$DUCKDB" :memory: ;;
         *.sh)  bash "$t" ;;
       esac >"$log" 2>&1; then
      echo "PASS  $name"
      passed=$((passed + 1))
    else
      echo "FAIL  $name"
      sed 's/^/      /' "$log"
      failed=$((failed + 1))
    fi
  done
  echo
  if [ "$failed" -eq 0 ]; then
    echo "TESTS OK ($passed/$passed passed)"
  else
    echo "TESTS FAILED ($failed of $((passed + failed)) failed)"
    return 1
  fi
}

require_duckdb

case "${1:-help}" in
  test)      run_tests ;;
  open-data) bash tools/fetch_open_data.sh ;;
  help|-h|--help) usage ;;
  *) echo "build.sh: unknown target '$1'" >&2; usage >&2; exit 2 ;;
esac
