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
  test [name...]
              Run every check in tests/ and report pass/fail, or only the
              named ones (e.g. ./build.sh test answer_key solution_chain.sh)
  data        Generate the clean truth (generator/truth/), the Warm-up
              extract (data/warmup/), the 2018-2020 Raw extract (data/raw/)
              and its Answer key (generator/dq_answer_key.parquet) from
              data/open/ (OUT_DIR overrides the output root)
  expected    Run every Challenge solution in chain order (w, c01..c10, t-*)
              in one fresh Work database and write expected/<output>.parquet
              (OUT_DIR overrides where expected/ is written)
  open-data   Re-download the frozen open data into data/open/ (needs network)
  setup       Build the Setup release dist/duckdb-bundle-YYYYMMDD.zip
              (first run needs network to fill .cache/setup/; DIST_DIR and
              BUNDLE_DATE override the folder and the date)
  email       Render the pre-workshop email to dist/pre-workshop-email.md
              (DRIVE_LINK fills the Drive link; BUNDLE_DATE and DIST_DIR as above)
  help        Show this message

Once per clone, run tests before every commit: git config core.hooksPath .githooks
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

# test [name...]: every tests/*.sql (or only the named ones) runs in a fresh
# in-memory DuckDB from the repo root, after tests/lib/assert.sql; it passes if
# DuckDB exits 0. Every tests/*.sh runs with DUCKDB exported; it passes if it
# exits 0. Later tickets add files.
run_tests() {
  local log passed=0 failed=0 t name want
  log="$(mktemp)"
  trap 'rm -f "$log"' RETURN

  local -a picked=()
  if [ "$#" -eq 0 ]; then
    picked=(tests/*.sql tests/*.sh)
  else
    # A name may leave out tests/ and the extension; it must match one file.
    for want in "$@"; do
      want="${want#tests/}"
      for t in "tests/$want" "tests/$want.sql" "tests/$want.sh"; do
        [ -f "$t" ] && { picked+=("$t"); continue 2; }
      done
      echo "build.sh: no test named '$want' in tests/" >&2; return 2
    done
  fi

  for t in "${picked[@]}"; do
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

# data: the generator (#21). Its SQL uses paths relative to the output root, so
# it runs there; a root other than the repo gets data/open/ and names.csv linked in.
build_data() {
  local out="${OUT_DIR:-.}" repo
  repo="$(pwd)"
  mkdir -p "$out/generator/truth" "$out/data/warmup" "$out/data/raw"
  out="$(cd "$out" && pwd)"
  if [ "$out" != "$repo" ]; then
    [ -e "$out/data/open" ] || ln -s "$repo/data/open" "$out/data/open"
    cp generator/names.csv "$out/generator/names.csv"
  fi
  cat generator/truth.sql generator/warmup.sql generator/raw.sql | (cd "$out" && "$DUCKDB" :memory:)
  echo "build.sh: wrote $out/generator/truth/, $out/generator/dq_answer_key.parquet, $out/data/warmup/ and $out/data/raw/"
}

# Challenge-card readers: challenge_cards, card_field, card_block, sql_cell.
# shellcheck source=tools/cards.sh
source tools/cards.sh

# expected: each Challenge's expected Parquet is its canonical solution's output
# (#5). The solutions share one Work database, so each one's input is the
# previous one's output, as for a Participant.
build_expected() {
  local out="${OUT_DIR:-.}" work card base table
  mkdir -p "$out/expected"
  out="$(cd "$out" && pwd)"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  while read -r card <&3; do
    base="$(basename "$card" .md)"
    table="$(card_field "$card" output)"
    { echo ".bail on"; cat "solutions/$base.sql"; } | "$DUCKDB" "$work/work.duckdb" >/dev/null
    "$DUCKDB" "$work/work.duckdb" -c \
      "COPY (FROM $table ORDER BY ALL) TO '$out/expected/$table.parquet' (FORMAT parquet, COMPRESSION zstd);"
    echo "build.sh: wrote $out/expected/$table.parquet"
  done 3< <(challenge_cards)
}

# setup: the Setup release (#14, #18). Paths inside the zip start at the bundle
# root, so a Participant extracts it straight into duckdb-bundle/.
build_setup() {
  local dist="${DIST_DIR:-dist}" date="${BUNDLE_DATE:-$(date +%Y%m%d)}" stage zip
  bash tools/fetch_setup_deps.sh
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' RETURN

  mkdir -p "$stage/bin" "$stage/data" "$stage/updates"
  cp -R .cache/setup/bin/. "$stage/bin/"
  cp -R .cache/setup/repo "$stage/repo"
  cp -R data/open "$stage/data/open"
  cp setup/install.sql setup/smoke_test.sql setup/start-workshop.command "$stage/"
  chmod 755 "$stage/start-workshop.command"
  # cmd.exe misreads batch files with LF line endings; Notepad users get CRLF too.
  crlf() { awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$1" >"$2"; }
  crlf setup/start-workshop.bat "$stage/start-workshop.bat"
  crlf setup/README.txt "$stage/README.txt"
  crlf setup/updates-README.txt "$stage/updates/README.txt"

  mkdir -p "$dist"
  zip="$(cd "$dist" && pwd)/duckdb-bundle-$date.zip"
  rm -f "$zip"
  (cd "$stage" && zip -q -r -X "$zip" . -x '*.DS_Store')
  echo "build.sh: wrote $zip"
}

# email: the pre-workshop email (#19). Steps 3-5 and the Mac block come from
# the setup card, so the email and cards/setup.md never drift apart.
build_email() {
  local dist="${DIST_DIR:-dist}" out
  mkdir -p "$dist"
  out="$dist/pre-workshop-email.md"
  bash tools/render_email.sh docs/pre-workshop-email.md >"$out"
  echo "build.sh: wrote $out"
}

require_duckdb

case "${1:-help}" in
  test)      shift; run_tests "$@" ;;
  data)      build_data ;;
  expected)  build_expected ;;
  open-data) bash tools/fetch_open_data.sh ;;
  setup)     build_setup ;;
  email)     build_email ;;
  help|-h|--help) usage ;;
  *) echo "build.sh: unknown target '$1'" >&2; usage >&2; exit 2 ;;
esac
