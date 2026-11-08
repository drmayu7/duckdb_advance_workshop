#!/usr/bin/env bash
# Frozen open data is byte-exact: both the working tree and the staged/committed
# blobs match data/open/SHA256SUMS (written by tools/fetch_open_data.sh).
set -u
cd "$(dirname "$0")/.." || exit 1
sums=data/open/SHA256SUMS
[ -f "$sums" ] || { echo "FAIL: $sums is missing (run ./build.sh open-data)"; exit 1; }
fail=0

listed="$(awk '{print $2}' "$sums" | sort)"
present="$(find data/open -maxdepth 1 -type f ! -name SHA256SUMS -exec basename {} \; | sort)"
if [ "$listed" != "$present" ]; then
  echo "FAIL: files in data/open/ differ from $sums:"
  diff <(echo "$listed") <(echo "$present") | sed 's/^/  /'
  fail=1
fi

while read -r want name; do
  path="data/open/$name"
  got="$(shasum -a 256 "$path" 2>/dev/null | awk '{print $1}')"
  [ "$got" = "$want" ] || { echo "FAIL: $name in working tree does not match $sums"; fail=1; continue; }
  # The index is what gets committed; catch line-ending or filter conversion.
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    blob="$(git show ":$path" | shasum -a 256 | awk '{print $1}')"
    [ "$blob" = "$want" ] || { echo "FAIL: $name as staged in git does not match $sums (line-ending conversion?)"; fail=1; continue; }
  fi
  echo "ok: $name"
done < "$sums"
exit $fail
