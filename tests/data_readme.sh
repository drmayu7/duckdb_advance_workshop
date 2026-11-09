#!/usr/bin/env bash
# The dataset README records a source and licence for every open-data file,
# and carries the synthetic-data banner (ADR 0003).
set -u
# shellcheck source=tests/lib/check.sh
. "$(dirname "$0")/lib/check.sh"
cd "$(dirname "$0")/.." || exit 1
readme=data/README.md
[ -f "$readme" ] || { bad "$readme is missing"; finish; }

if grep -qi "synthetic data, not real hospital performance" "$readme"; then
  ok "synthetic-data banner"
else
  bad "synthetic-data banner missing from $readme"
fi

# Each file must appear in a Markdown table row that names a source URL and a licence.
for f in data/open/*; do
  name="$(basename "$f")"
  [ "$name" = SHA256SUMS ] && continue
  row="$(grep -F "\`$name\`" "$readme" | grep '^|' | head -1)"
  if [ -z "$row" ]; then
    bad "$name has no row in $readme"
  elif ! grep -q 'https://' <<<"$row"; then
    bad "$name row has no source URL"
  elif ! grep -qiE 'CC BY|licen[cs]e|attribut' <<<"$row"; then
    bad "$name row has no licence"
  else
    ok "$name"
  fi
done
finish
