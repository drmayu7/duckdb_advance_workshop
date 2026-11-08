#!/usr/bin/env bash
# The dataset README records a source and licence for every open-data file,
# and carries the synthetic-data banner (ADR 0003).
set -u
cd "$(dirname "$0")/.." || exit 1
readme=data/README.md
fail=0
[ -f "$readme" ] || { echo "FAIL: $readme is missing"; exit 1; }

if grep -qi "synthetic data, not real hospital performance" "$readme"; then
  echo "ok: synthetic-data banner"
else
  echo "FAIL: synthetic-data banner missing from $readme"; fail=1
fi

# Each file must appear in a Markdown table row that names a source URL and a licence.
for f in data/open/*; do
  name="$(basename "$f")"
  row="$(grep -F "\`$name\`" "$readme" | grep '^|' | head -1)"
  if [ -z "$row" ]; then
    echo "FAIL: $name has no row in $readme"; fail=1
  elif ! grep -q 'https://' <<<"$row"; then
    echo "FAIL: $name row has no source URL"; fail=1
  elif ! grep -qiE 'CC BY|licen[cs]e|attribut' <<<"$row"; then
    echo "FAIL: $name row has no licence"; fail=1
  else
    echo "ok: $name"
  fi
done
exit $fail
