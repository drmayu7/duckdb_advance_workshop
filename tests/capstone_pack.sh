#!/usr/bin/env bash
# The Capstone pack (#10, #31), as Participants and the facilitator read it:
# the brief, rubric, score slip and template that ship in the Content release;
# the three Hint cards and capstone_truth/ that don't. What ships must not give
# the Held-back defects away, and a Hint card describes a symptom only.
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }
banner="Synthetic data, not real hospital performance"

for f in capstone/brief.md capstone/brief_template.md capstone/rubric.md capstone/score_slip.md \
         capstone/hints.md capstone/scores.csv capstone/scores.sql capstone_truth/README.md capstone_truth/check.sql; do
  [ -s "$f" ] || bad "$f is missing or empty"
done
[ "$fail" = 0 ] && ok "every file of the pack is there"

for f in capstone/brief.md capstone/brief_template.md capstone/rubric.md; do
  if grep -q "$banner" "$f"; then ok "$f carries the synthetic-data banner"; else bad "$f has no synthetic-data banner"; fi
done

# The template's headings are the talk order (#10), and the banner comes last.
got="$(grep -E '^## ' capstone/brief_template.md | sed 's/^## [0-9.]* *//' | tr '\n' '|')"
want="The answer to the Director|The data-quality story|The pipeline|One caveat|"
if [ "$got" = "$want" ]; then ok "brief_template.md headings: answer, data-quality story, pipeline, caveat"
else bad "brief_template.md headings are '$got', want '$want'"; fi
if [ "$(grep -n . capstone/brief_template.md | tail -1 | grep -c "$banner")" = 1 ]; then ok "the template ends with the banner"
else bad "the template's last line is not the banner"; fi

# The brief names each Angle's summary table and the four sanity checks.
for t in readmit_2021 dengue_2021 hospital_load_2021; do
  grep -q "\`$t\`" capstone/brief.md || bad "the brief does not name the summary table $t"
done
n="$(grep -cE '^\*\*[0-9]\. ' capstone/brief.md)"
if [ "$n" = 4 ]; then ok "the brief has 4 sanity checks"; else bad "the brief has $n sanity checks, want 4"; fi
for d in '-- RAW' '-- CLEAN' '-- SUMMARY' '-- DQ FIX:'; do
  grep -qF -- "$d" capstone/brief.md || bad "the brief does not ask for the '$d' header"
done

# The rubric: 4 criteria, scored 1 to 4.
rows="$(grep -cE '^\| \*\*' capstone/rubric.md)"
if [ "$rows" = 4 ] && grep -q '^| Criterion | 1 | 2 | 3 | 4 |' capstone/rubric.md; then ok "the rubric has 4 criteria scored 1-4"
else bad "the rubric has $rows criteria rows, or no 1-4 header"; fi

# Three Hint cards, one per Angle.
cards="$(grep -E '^## Hint card' capstone/hints.md)"
if [ "$(grep -c . <<<"$cards")" = 3 ] && grep -q 'Angle A' <<<"$cards" && grep -q 'Angle B' <<<"$cards" && grep -q 'Angle C' <<<"$cards"; then
  ok "hints.md has three Hint cards, Angles A, B and C"
else bad "hints.md cards are: $cards"; fi

# No spoilers: nothing that ships, and no Hint card, names a Held-back defect's
# code, cause or fix. (hints.md and capstone_truth/ never ship; the cards are
# still symptom-only, #10.)
spoiler='ID06|DX04|DT02|passport|non-MyKad|police|army|month first|MM/DD|free[- ]text|typed as text|norm_mykad|other_id|Queen Elizabeth'
checked=0
for f in capstone/*.md; do
  checked=$((checked + 1))
  if hits="$(grep -n -i -E "$spoiler" "$f")"; then bad "$f gives a Held-back defect away:"$'\n'"$hits"; fi
done
[ "$checked" -ge 5 ] || bad "only $checked capstone/*.md files checked for spoilers"
[ "$fail" = 0 ] && ok "no Capstone document or Hint card names a Held-back defect, its cause or its fix"

# scores.sql runs on the committed, still-empty scores.csv.
if out="$("$DUCKDB" -csv :memory: <capstone/scores.sql 2>&1)"; then ok "scores.sql runs on the empty scores.csv"
else bad "scores.sql fails on the committed scores.csv: $out"; fi
exit $fail
