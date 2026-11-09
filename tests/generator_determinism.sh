#!/usr/bin/env bash
# The generator is deterministic: two runs of `build.sh data` write byte-identical
# files, and the committed generated data is what the generator writes today.
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Every file the generator must write, relative to the output root.
outputs="generator/truth/patient.parquet
generator/truth/admission.parquet
data/warmup/patient_2017.parquet
data/warmup/admission_2017.parquet
generator/dq_answer_key.parquet
data/raw/manifest.csv
data/capstone/manifest.csv
capstone_truth/readmit_2021.parquet
capstone_truth/dengue_2021.parquet
capstone_truth/hospital_load_2021.parquet
$(for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
    printf 'data/raw/2018-%s.csv\ndata/raw/2019-%s.json\ndata/raw/2020-%s.parquet\n' "$m" "$m" "$m"
    printf 'data/capstone/2021-%s.parquet\ndata/capstone/2021-%s-sabah.csv\n' "$m" "$m"
  done)"

# A run takes about 2 s. A slow one is a regression the other checks can't see
# (and the pre-commit hook pays for it twice): usually a non-equi join or a
# correlated NOT IN. Find the statement with `.timer on` in the generator SQL.
max_seconds=20
for run in a b; do
  start=$SECONDS
  if ! OUT_DIR="$tmp/$run" "$root/build.sh" data >"$tmp/$run.log" 2>&1; then
    bad "build.sh data (run $run) exited non-zero:"; sed 's/^/  /' "$tmp/$run.log"; finish
  fi
  took=$((SECONDS - start))
  if [ "$took" -gt "$max_seconds" ]; then
    bad "build.sh data (run $run) took ${took}s, over ${max_seconds}s: profile the generator with .timer on"
  else
    ok "build.sh data (run $run) took ${took}s"
  fi
done

sums() { # sums <dir>: sha256 of every generated file, by relative path
  (cd "$1" && find generator data/warmup data/raw data/capstone capstone_truth -type f 2>/dev/null | LC_ALL=C sort | xargs shasum -a 256)
}

while read -r f; do
  if [ -f "$tmp/a/$f" ]; then ok "generator writes $f"; else bad "generator did not write $f"; fi
done <<<"$outputs"

if [ "$(sums "$tmp/a")" = "$(sums "$tmp/b")" ]; then
  ok "two generator runs are byte-identical"
else
  bad "two generator runs differ:"; diff <(sums "$tmp/a") <(sums "$tmp/b") | sed 's/^/  /'
fi

mark
while read -r f; do
  if ! cmp -s "$tmp/a/$f" "$root/$f"; then
    bad "committed $f is stale or missing (run ./build.sh data)"
  fi
done <<<"$outputs"
failed || ok "committed generated data is up to date"
finish
