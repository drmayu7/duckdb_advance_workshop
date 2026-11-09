#!/usr/bin/env bash
# The Held-back defects bite (#16 Seam 1, #31). At a bundle root, the C4-C9
# solutions run unchanged on the 2021 Capstone extract, between the reference
# Capstone stages in capstone_truth/: raw.sql (the C1/C3 read, adapted to the
# 2021 files), the documented fixes, and summary.sql (the three Angle tables,
# written as Parquet as a team delivers them). The facilitator's diff
# (check.sql) then compares each Angle with capstone_truth/:
#   * with no fix, Angles A, B and C all differ from the truth;
#   * with every fix, all three match;
#   * leaving out one fix makes its own Angle differ (ID06 -> A, DX04 -> B,
#     DT02 -> C), so each defect moves its Angle's number on its own.
# The brief's sanity checks run on the unfixed pipeline without an error.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

bundle="$tmp/duckdb-bundle"
mkdir -p "$bundle/data"
cp -R "$root/solutions" "$root/expected" "$root/capstone" "$root/capstone_truth" "$bundle/"
cp -R "$root/data/capstone" "$bundle/data/capstone"
ln -s "$root/data/open" "$bundle/data/open"
cd "$bundle" || exit 1

# run <name> <fix...>: the pipeline in a fresh Work database, in its own folder
# (summary.sql writes its Parquet next to the database); prints check.sql's
# verdict for Angles A, B and C, one line each.
run() {
  local name="$1" f out; shift
  local -a fixes=("$@")
  has() { local x; for x in ${fixes[@]+"${fixes[@]}"}; do [ "$x" = "$1" ] && return 0; done; return 1; }
  mkdir -p "$name"; ln -sfn ../data "$name/data"; ln -sfn ../expected "$name/expected"
  ln -sfn ../capstone_truth "$name/capstone_truth"
  {
    echo ".bail on"
    cat capstone_truth/reference/raw.sql
    for f in dt02 dx04; do has "$f" && cat "capstone_truth/reference/fix_$f.sql"; done
    cat solutions/c04-fix-types.sql solutions/c05-facilities.sql solutions/c06-dedupe.sql
    has id06 && cat capstone_truth/reference/fix_id06.sql
    cat solutions/c07-hospital-load.sql solutions/c08-episode.sql solutions/c09-readmission.sql
    cat capstone_truth/reference/summary.sql
  } >"$name/pipeline.sql"
  # run is called in $(...), so a failure is recorded in a file, not in $fail.
  if ! out="$(cd "$name" && "$DUCKDB" work.duckdb <pipeline.sql 2>&1 >/dev/null)"; then
    echo "$name: pipeline failed: $out" >>pipeline_failures; return 1
  fi
  (cd "$name" && "$DUCKDB" -list -noheader :memory: -c ".read capstone_truth/check.sql" \
     -c "FROM check_readmit('readmit_2021.parquet')" -c "FROM check_dengue('dengue_2021.parquet')" \
     -c "FROM check_load('hospital_load_2021.parquet')") 2>&1
}

# expect <name> <verdicts> <want...>: each of A, B, C "matches" or "differs".
expect() {
  local name="$1" got="$2" angle line i=0; shift 2
  for angle in A B C; do
    i=$((i + 1)); line="$(sed -n "${i}p" <<<"$got")"
    case "$1:$line" in
      matches:matches) ok "$name: Angle $angle matches capstone_truth/" ;;
      differs:*\ differ|differs:*\ differs) ok "$name: Angle $angle differs from capstone_truth/ ($line)" ;;
      -:*) ;;  # not asserted: a defect may touch another Angle too
      *) bad "$name: Angle $angle should be '$1', check.sql says '$line'" ;;
    esac
    shift
  done
}

expect "no fix (C1-C10 logic unadapted)" "$(run nofix)" differs differs differs

# Visibly, not just in one row (#10): each defect moves its Angle's figure by
# far more than year-to-year noise, where a team would look.
visible() { # visible <description> <SQL giving true when the effect is there>
  local got
  got="$("$DUCKDB" -list -noheader nofix/work.duckdb -c "$2" 2>&1)"
  if [ "$got" = true ]; then ok "no fix: $1"; else bad "no fix: $1 (got '$got')"; fi
}
visible "ID06 drops Sabah's diabetes index episodes by more than a tenth" \
  "SELECT r.index_episodes < 0.9 * t.index_episodes FROM readmit_2021 r
   JOIN 'capstone_truth/readmit_2021.parquet' t USING (state) WHERE state = 'SABAH'"
visible "ID06 moves Sabah's readmission rate by more than a point" \
  "SELECT abs(r.readmit_pct - t.readmit_pct) > 1 FROM readmit_2021 r
   JOIN 'capstone_truth/readmit_2021.parquet' t USING (state) WHERE state = 'SABAH'"
visible "DX04 drops 2021 dengue admissions by more than a quarter" \
  "SELECT (SELECT sum(dengue_admissions) FROM dengue_2021)
          < 0.75 * (SELECT sum(dengue_admissions) FROM 'capstone_truth/dengue_2021.parquet')"
visible "DT02 at least doubles Hospital Queen Elizabeth's bed days" \
  "SELECT h.bed_days > 2 * t.bed_days FROM hospital_load_2021 h
   JOIN 'capstone_truth/hospital_load_2021.parquet' t USING (facility_code) WHERE facility_code = '11-12060025'"

# The brief's sanity checks, as a team pastes them, run on the unfixed pipeline.
awk '/^## Sanity checks/ { on = 1; next } on && /^## / { on = 0 }
     on && /^```sql/ { n++; f = sprintf("sanity_%d.sql", n); next }
     on && /^```/ { f = ""; next }
     f { print > f }' capstone/brief.md
checks=0
for f in sanity_*.sql; do
  [ -e "$f" ] || continue
  checks=$((checks + 1))
  if out="$("$DUCKDB" -csv nofix/work.duckdb <"$f" 2>&1)"; then ok "the brief's sanity check $f runs"
  else bad "the brief's sanity check $f fails: $out"; fi
done
[ "$checks" = 4 ] || bad "found $checks sanity-check cells in capstone/brief.md, want 4"
# What they show an unfixed team: undated admissions (DT02) and admissions
# with no patient (ID06), where the clean extract has none.
visible "sanity check 2 shows admissions with no admit date" \
  "SELECT count(*) FILTER (WHERE admit_date IS NULL) > 0 FROM admission_typed"
visible "sanity check 3 shows admissions with no patient" \
  "SELECT count(*) FILTER (WHERE patient_key IS NULL) > 0 FROM admission_clean"

expect "every fix" "$(run allfix dt02 dx04 id06)" matches matches matches
expect "every fix but ID06" "$(run no_id06 dt02 dx04)" differs - -
expect "every fix but DX04" "$(run no_dx04 dt02 id06)" - differs -
expect "every fix but DT02" "$(run no_dt02 dx04 id06)" - - differs
if [ -s pipeline_failures ]; then bad "pipelines failed:"; sed 's/^/  /' pipeline_failures; fi
exit $fail
