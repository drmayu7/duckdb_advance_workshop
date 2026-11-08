#!/usr/bin/env bash
# PROTOTYPE, wipe me.   Usage:  bash prototypes/challenge-card/run.sh A|B|C
# Builds a throwaway database, prints the variant's card, then plays a Participant who makes
# two common mistakes before getting it right, running that variant's Self-check after each attempt.
set -euo pipefail
cd "$(dirname "$0")"
V="${1:-A}"
DB=PROTOTYPE_wipe_me.duckdb
rm -f "$DB"
duckdb "$DB" -c ".read setup.sql" -c ".read variant-c/build_expected.sql" \
             -c ".read variant-b/stubs.sql" -c ".read variant-b/checks.sql" >/dev/null

say() { printf '\n\033[1;36m━━ %s\033[0m\n' "$*"; }

check_a() {
  duckdb "$DB" -c "SELECT count(*) AS index_admissions, count_if(readmit_30d) AS readmissions,
    left(md5(string_agg(format('{}:{}', admission_id, readmit_30d), ',' ORDER BY admission_id)), 8) AS fingerprint
    FROM ch13_readmit"
  echo "   expected (from the card):  4440 | 606 | 8a166ede"
}
check_b() { duckdb "$DB" -c "FROM check_ch13_core()"; }
check_c() {
  (cd variant-c && duckdb "../$DB" -c "SELECT count(*) AS rows_differ FROM (
     (FROM ch13_readmit EXCEPT FROM 'expected/ch13_readmit.parquet') UNION ALL
     (FROM 'expected/ch13_readmit.parquet' EXCEPT FROM ch13_readmit))")
}

case "$V" in
  A|a) CARD=variant-a/challenge-1.3.md;  CHECK=check_a ;;
  B|b) CARD=variant-b/challenge-1.3.sql; CHECK=check_b ;;
  C|c) CARD=variant-c/challenge-1.3.md;  CHECK=check_c ;;
  *) echo "usage: $0 A|B|C"; exit 1 ;;
esac

say "THE CARD ($CARD)"; cat "$CARD"
say "Attempt 1: kept the deaths";              duckdb "$DB" -c ".read mistakes/m1_kept_deaths.sql";     $CHECK
say "Attempt 2: counted from admit_date";      duckdb "$DB" -c ".read mistakes/m3_from_admit_date.sql"; $CHECK
say "Attempt 3: used LAG instead of LEAD";     duckdb "$DB" -c ".read mistakes/m2_used_lag.sql";        $CHECK
say "Attempt 4: correct";                      duckdb "$DB" -c ".read solution.sql";                    $CHECK
say "Try it yourself in the UI:  cd $(pwd)/variant-$(echo "$V" | tr A-Z a-z) && duckdb -ui ../$DB"
