#!/usr/bin/env bash
# The large dataset and its demos (#25), at the small truth's scale so it runs
# in seconds: `build.sh large` with LARGE_PATIENTS=58000 must write exactly the
# small truth's 2018-2021 admissions, Hive-partitioned by year, twice
# byte-identically, plus the take-home zip; large/ is never committed; and the
# demo SQL in demos/m1/ and demos/m3/ runs against it (the S3 demo with the
# bucket swapped for the local folder, since tests have no AWS access).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }
q()   { "$DUCKDB" -list -noheader :memory: -c "$1"; }

for run in a b; do
  if ! LARGE_PATIENTS=58000 OUT_DIR="$tmp/$run" DIST_DIR="$tmp/$run/dist" "$root/build.sh" large >"$tmp/$run.log" 2>&1; then
    echo "FAIL: build.sh large (run $run) exited non-zero:"; sed 's/^/  /' "$tmp/$run.log"; exit 1
  fi
done
large="$tmp/a/large"

# Layout: year=YYYY folders for 2018-2021 only, one part per quarter, plus patients.
want="$(for y in 2018 2019 2020 2021; do for p in 1 2 3 4; do echo "admission/year=$y/part-$p.parquet"; done; done
        printf '%s\n' patient.parquet README.txt)"
got="$(cd "$large" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)"
if [ "$got" = "$(LC_ALL=C sort <<<"$want")" ]; then ok "large/ holds 16 quarter parts, patient.parquet and README.txt"
else bad "large/ layout differs:"; diff <(LC_ALL=C sort <<<"$want") <(echo "$got") | sed 's/^/  /'; fi

sums() { (cd "$1" && find large -type f | LC_ALL=C sort | xargs shasum -a 256); }
if [ "$(sums "$tmp/a")" = "$(sums "$tmp/b")" ]; then ok "two runs are byte-identical"
else bad "two runs differ:"; diff <(sums "$tmp/a") <(sums "$tmp/b") | sed 's/^/  /'; fi

if grep -qF 'Synthetic data, not real hospital performance.' "$large/README.txt"; then ok "README.txt has the synthetic-data banner"
else bad "README.txt has no synthetic-data banner"; fi

# year is Hive-style: in the folder name, not in the files.
n="$(q "SELECT count(*) FROM parquet_schema('$large/admission/*/*.parquet') WHERE name = 'year'")"
if [ "$n" = 0 ]; then ok "no year column inside the files"; else bad "$n files carry a year column"; fi

# 58000 patients is the small truth's scale, so the large data is its 2018-2021 rows.
cd "$root" || exit 1
diffs="$(q "WITH l AS (SELECT * EXCLUDE (year) FROM read_parquet('$large/admission/*/*.parquet')),
                 t AS (FROM 'generator/truth/admission.parquet' WHERE year(admit_ts) BETWEEN 2018 AND 2021)
            SELECT (SELECT count(*) FROM (FROM l EXCEPT ALL FROM t)) + (SELECT count(*) FROM (FROM t EXCEPT ALL FROM l))")"
if [ "$diffs" = 0 ]; then ok "admissions are the truth's 2018-2021 admissions"; else bad "$diffs admission rows differ from the truth"; fi

n="$(q "SELECT count(*) FROM read_parquet('$large/admission/*/*.parquet', filename = true)
        WHERE year <> year(admit_ts)
           OR NOT ends_with(filename, '/part-' || quarter(admit_ts) || '.parquet')")"
if [ "$n" = 0 ]; then ok "each admission is in its year folder and quarter part"; else bad "$n admissions in the wrong file"; fi

diffs="$(q "WITH l AS (FROM '$large/patient.parquet'),
                 t AS (FROM 'generator/truth/patient.parquet' WHERE patient_id IN
                        (SELECT patient_id FROM 'generator/truth/admission.parquet' WHERE year(admit_ts) BETWEEN 2018 AND 2021))
            SELECT (SELECT count(*) FROM (FROM l EXCEPT ALL FROM t)) + (SELECT count(*) FROM (FROM t EXCEPT ALL FROM l))")"
if [ "$diffs" = 0 ]; then ok "patient.parquet is every patient with a 2018-2021 admission"; else bad "$diffs patient rows differ"; fi

# The take-home zip holds large/ and nothing else.
zip="$tmp/a/dist/duckdb-large-2018-2021.zip"
if [ -f "$zip" ]; then
  zgot="$(zipinfo -1 "$zip" | grep -v '/$' | LC_ALL=C sort)"
  zwant="$(while read -r f; do echo "large/$f"; done <<<"$want" | LC_ALL=C sort)"
  if [ "$zgot" = "$zwant" ]; then ok "zip holds exactly large/"
  else bad "zip paths differ:"; diff <(echo "$zwant") <(echo "$zgot") | sed 's/^/  /'; fi
else bad "no $zip"; fi

# Never committed: large/ at the repo root (the default OUT_DIR) is ignored.
if git -C "$root" check-ignore -q large/admission/year=2018/part-1.parquet; then ok "large/ is git-ignored"
else bad "large/ is not git-ignored"; fi

# The demos run from the bundle root, where the take-home zip unpacks large/.
bundle="$tmp/a"
ln -s "$root/data" "$bundle/data"; ln -s "$root/expected" "$bundle/expected"

if (cd "$bundle" && { echo ".bail on"; cat "$root/demos/m1/csv-vs-parquet.sql"; } | "$DUCKDB" demo.duckdb) >"$tmp/m1.log" 2>&1; then
  ok "demos/m1/csv-vs-parquet.sql runs"
  n="$(q "SELECT (SELECT count(*) FROM read_csv('$bundle/admission_2018_2021.csv')) = (SELECT count(*) FROM '$large/admission/*/*.parquet')")"
  if [ "$n" = true ]; then ok "the demo CSV has every large admission"; else bad "the demo CSV row count differs"; fi
else bad "demos/m1/csv-vs-parquet.sql failed:"; sed 's/^/  /' "$tmp/m1.log"; fi

# The S3 demo, offline: drop the setup cell (secret, extensions) and read the
# local large/ in place of the bucket.
s3=demos/m3/s3-demo.sql
if grep -q "s3://duckdb-series2-2026/large/" "$root/$s3" && grep -q "PROVIDER credential_chain" "$root/$s3"; then
  ok "$s3 reads the bucket with a credential_chain secret"
else bad "$s3 does not read s3://duckdb-series2-2026/large/ with a credential_chain secret"; fi
sed -e '/-- begin setup/,/-- end setup/d' -e '/which_secret/d' \
    -e "s|s3://duckdb-series2-2026/large/|$large/|g" "$root/$s3" >"$tmp/s3-local.sql"
if (cd "$bundle" && { echo ".bail on"; echo "CALL enable_logging('HTTP', storage = 'memory');"; cat "$tmp/s3-local.sql"; } | "$DUCKDB" demo.duckdb) >"$tmp/m3.log" 2>&1; then
  ok "$s3 runs (against the local copy)"
  n="$(q "SELECT count(*) FROM '$bundle/hospital_load_national.parquet'")"
  if [ "$n" = 10 ]; then ok "hospital_load_national.parquet has the top 10 hospitals"; else bad "hospital_load_national.parquet has $n rows, not 10"; fi
else bad "$s3 failed:"; sed 's/^/  /' "$tmp/m3.log"; fi
exit $fail
