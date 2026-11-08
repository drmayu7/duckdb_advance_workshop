#!/usr/bin/env bash
# The generator is deterministic: two runs of `build.sh data` write byte-identical
# files, and the committed generated data is what the generator writes today.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

# Every file the generator must write, relative to the output root.
outputs="generator/truth/patient.parquet
generator/truth/admission.parquet
data/warmup/patient_2017.parquet
data/warmup/admission_2017.parquet"

for run in a b; do
  if ! OUT_DIR="$tmp/$run" "$root/build.sh" data >"$tmp/$run.log" 2>&1; then
    echo "FAIL: build.sh data (run $run) exited non-zero:"; sed 's/^/  /' "$tmp/$run.log"; exit 1
  fi
done

sums() { # sums <dir>: sha256 of every generated file, by relative path
  (cd "$1" && find generator data/warmup -type f 2>/dev/null | LC_ALL=C sort | xargs shasum -a 256)
}

while read -r f; do
  if [ -f "$tmp/a/$f" ]; then echo "ok: generator writes $f"; else echo "FAIL: generator did not write $f"; fail=1; fi
done <<<"$outputs"

if [ "$(sums "$tmp/a")" = "$(sums "$tmp/b")" ]; then
  echo "ok: two generator runs are byte-identical"
else
  echo "FAIL: two generator runs differ:"; diff <(sums "$tmp/a") <(sums "$tmp/b") | sed 's/^/  /'; fail=1
fi

while read -r f; do
  if ! cmp -s "$tmp/a/$f" "$root/$f"; then
    echo "FAIL: committed $f is stale or missing (run ./build.sh data)"; fail=1
  fi
done <<<"$outputs"
[ "$fail" = 0 ] && echo "ok: committed generated data is up to date"
exit $fail
