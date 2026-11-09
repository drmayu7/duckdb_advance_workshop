#!/usr/bin/env bash
# Frozen open data is byte-exact: both the working tree and the staged/committed
# blobs match data/open/SHA256SUMS (written by tools/fetch_open_data.sh).
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
cd "$(dirname "$0")/.." || exit 1
sums=data/open/SHA256SUMS
[ -f "$sums" ] || { bad "$sums is missing (run ./build.sh open-data)"; finish; }

listed="$(awk '{print $2}' "$sums" | sort)"
present="$(find data/open -maxdepth 1 -type f ! -name SHA256SUMS -exec basename {} \; | sort)"
if [ "$listed" != "$present" ]; then
  bad "files in data/open/ differ from $sums:"
  diff <(echo "$listed") <(echo "$present") | sed 's/^/  /'
fi

while read -r want name; do
  path="data/open/$name"
  got="$(shasum -a 256 "$path" 2>/dev/null | awk '{print $1}')"
  [ "$got" = "$want" ] || { bad "$name in working tree does not match $sums"; continue; }
  # The index is what gets committed; catch line-ending or filter conversion.
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    blob="$(git show ":$path" | shasum -a 256 | awk '{print $1}')"
    [ "$blob" = "$want" ] || { bad "$name as staged in git does not match $sums (line-ending conversion?)"; continue; }
  fi
  ok "$name"
done < "$sums"
finish
