#!/usr/bin/env bash
# build.sh test fails a SQL test whose assert_eq statement returns no rows, so
# a check over a set can't pass vacuously (CODING_STANDARDS.md, "Tests"; #30's
# retro). It runs build.sh's own harness on small test files in a scratch copy.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
indent() { sed 's/^/  /'; }

mkdir -p "$tmp/tests/lib" "$tmp/tools"
cp "$root/build.sh" "$tmp/"
cp "$root/tests/lib/assert.sql" "$tmp/tests/lib/"
cp "$root/tools/cards.sh" "$tmp/tools/"

cat >"$tmp/tests/sound.sql" <<'EOF'
SELECT assert_eq('a scalar check', 1, 1);
-- A check that spans lines and returns one row per value.
SELECT assert_eq('row ' || x, x, x)
FROM range(2) r(x);
CREATE TABLE t AS SELECT 1 AS x;
SELECT assert_eq('a semicolon; in a name', 'a;b', 'a;b');
EOF
cat >"$tmp/tests/vacuous.sql" <<'EOF'
SELECT assert_eq('a scalar check', 1, 1);
SELECT assert_eq('three rows, said to be five', count(*), 5)
FROM range(3) HAVING count(*) = 5;
SELECT assert_eq('a later check', 2, 2);
EOF

out="$(cd "$tmp" && ./build.sh test sound 2>&1)"
if grep -q '^PASS  sound.sql' <<<"$out"; then ok "a test whose every check returns rows passes"
else bad "a sound test did not pass:"; indent <<<"$out"; fi

out="$(cd "$tmp" && ./build.sh test vacuous 2>&1)"
if grep -q '^FAIL  vacuous.sql' <<<"$out"; then ok "a test with a check that returns no rows fails"
else bad "a vacuous check passed:"; indent <<<"$out"; fi
if grep -q "returned no rows: SELECT assert_eq('three rows, said to be five'" <<<"$out"; then ok "the failure names the check"
else bad "the failure does not name the vacuous check:"; indent <<<"$out"; fi
finish
