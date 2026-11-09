#!/usr/bin/env bash
# The peer-review results (#10, #31): the facilitator types the score slips into
# capstone/scores.csv over lunch, and capstone/scores.sql computes each team's
# per-criterion averages live in DuckDB at 2.45. It also lists any row that
# can't be right (a score outside 1-4, or a team scoring itself).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

want_header="slip,scorer_team,team,answer,dq_story,pipeline,communication,did_well"
got_header="$(head -1 "$root/capstone/scores.csv" | tr -d '\r')"
if [ "$got_header" = "$want_header" ]; then ok "scores.csv has the slip's columns"
else bad "scores.csv header is '$got_header', want '$want_header'"; fi

mkdir -p "$tmp/capstone"
cp "$root/capstone/scores.sql" "$tmp/capstone/"
# run: scores.sql from the repo root, as the facilitator runs it; CSV output.
run() { (cd "$tmp" && "$DUCKDB" -csv :memory: <capstone/scores.sql 2>&1); }

# Three slips, each scoring the two other teams. Averages worked by hand:
# A gets (3, 4, 4, 3) and (1, 2, 4, 2); B (4, 3, 3, 4) and (3, 3, 3, 3);
# C (2, 2, 3, 3) and (4, 3, 2, 3).
cat >"$tmp/capstone/scores.csv" <<'EOF'
slip,scorer_team,team,answer,dq_story,pipeline,communication,did_well
1,A,B,4,3,3,4,"Clear before and after, with the numbers"
1,A,C,2,2,3,3,Good live query
2,B,A,3,4,4,3,The story was easy to follow
2,B,C,4,3,2,3,"A sharp caveat"
3,C,A,1,2,4,2,Pipeline ran clean
3,C,B,3,3,3,3,Answered every question
EOF
out="$(run)"
for line in "team,slips,answer,dq_story,pipeline,communication" "A,2,2.0,3.0,4.0,2.5" "B,2,3.5,3.0,3.0,3.5" "C,2,3.0,2.5,2.5,3.0"; do
  if grep -qx "$line" <<<"$out"; then ok "averages: $line"; else bad "averages: no line '$line' in:"$'\n'"$out"; fi
done
if grep -qx "A,Pipeline ran clean" <<<"$out" && grep -qx "B,Answered every question" <<<"$out"; then
  ok "lists each team's strengths"
else bad "strengths missing from:"$'\n'"$out"; fi
if grep -qE "team scored itself|score outside 1-4" <<<"$out"; then bad "a clean scores.csv was reported as having problems:"$'\n'"$out"
else ok "a clean scores.csv has no problem rows"; fi

# A typo (a 5) and a team scoring itself are listed, not averaged silently.
cat >>"$tmp/capstone/scores.csv" <<'EOF'
4,A,A,4,4,4,4,Ourselves
4,A,B,5,3,3,3,Typo
EOF
out="$(run)"
if grep -q "team scored itself" <<<"$out" && grep -q "score outside 1-4" <<<"$out"; then
  ok "lists a team scoring itself and a score outside 1-4"
else bad "bad rows not listed:"$'\n'"$out"; fi
exit $fail
