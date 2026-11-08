#!/usr/bin/env bash
# Re-download the bundle's Malaysian open data into data/open/ (needs network).
# The outputs are committed as frozen copies; run this only to refresh them
# deliberately, then re-run `./build.sh test` and review the diff.
# Sources and licences: data/README.md. Called by `./build.sh open-data`.
set -euo pipefail

cd "$(dirname "$0")/.."
DUCKDB="${DUCKDB:-duckdb}"
OUT=data/open
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$OUT"

get() { # get <url> <file>
  echo "fetch $1"
  curl -sSfL --retry 3 -o "$2" "$1"
}

# D1, D2: DOSM population (CC BY 4.0), unchanged.
get https://storage.dosm.gov.my/population/population_state.parquet    "$OUT/population_state.parquet"
get https://storage.dosm.gov.my/population/population_district.parquet "$OUT/population_district.parquet"

# D5: MoH bed utilisation per hospital, unchanged.
get https://raw.githubusercontent.com/MoH-Malaysia/data-resources-public/main/bedutil_facility.csv "$OUT/bed_utilisation.csv"

# D6, D7: DOSM state and district boundaries, unchanged.
get https://raw.githubusercontent.com/dosm-malaysia/data-open/main/datasets/geodata/administrative_1_state.geojson    "$OUT/geo_state.geojson"
get https://raw.githubusercontent.com/dosm-malaysia/data-open/main/datasets/geodata/administrative_2_district.geojson "$OUT/geo_district.geojson"

# D8: archived MoH dengue cases by state x age group x year, wide, unchanged.
get "https://archive.data.gov.my/data/dataset/b36d588f-ced4-4c16-ba9a-021e9bf38ae5/resource/216eb37a-d676-4c53-9f54-878e91a98e47/download/_202301090525170_bilangan-kes-penyakit-denggi-tahunan-mengikut-negeri-dan-kumpulan-umur.csv" \
    "$OUT/dengue_state_age_2018_2021.csv"

# D4: MoH facilities master, re-serialised as a JSON array. Every value is kept
# as text (exactly as in the CSV, newlines and all) except LATITUD/LONGITUD;
# only the pandas row-number column `Index` is dropped.
get https://raw.githubusercontent.com/MoH-Malaysia/data-resources-public/main/facilities_master.csv "$tmp/facilities_master.csv"
"$DUCKDB" :memory: -bail -c "
COPY (
  SELECT * EXCLUDE (\"Index\", LATITUD, LONGITUD),
         LATITUD::DOUBLE AS LATITUD, LONGITUD::DOUBLE AS LONGITUD
  FROM read_csv('$tmp/facilities_master.csv', all_varchar = true)
  ORDER BY \"Index\"::INTEGER
) TO '$OUT/facilities.json' (FORMAT json, ARRAY true);"

# ref_icd10: a small curated WHO ICD-10 subset, titles taken from the WHO
# browser. Each entry is a category whose valid codes (its children, or the
# category itself when it has none) go in, tagged with its Scenario group.
# A90/A91 were deleted from WHO ICD-10 in 2016 (replaced by A97) but are kept
# as legacy dengue codes, titled from the 2010 edition.
icd_groups="
diabetes E10 E11 E13 E14
dengue A90 A91 A97
cardiovascular I10 I11 I20 I21 I50 I63 I64
respiratory J18 J44 J45
renal N17 N18
infection A09 A41 N39
obstetric O14 O24 O80 O82
surgical K35 K80
injury S72
"
# Leaf categories (no children) get their title from their block's listing.
icd_blocks="2019:I10-I15 2019:I60-I69 2010:A90-A99"

who_get() { # who_get <edition> <concept id> <file>; WHO answers 404 when a concept has no children
  local url="https://icd.who.int/browse10/$1/en/JsonGetChildrenConcepts?useHtml=false&ConceptId=$2" code
  echo "fetch $url"
  code="$(curl -sSL --retry 3 -o "$3" -w '%{http_code}' "$url")"
  case "$code" in
    200) ;;
    404) echo '[]' > "$3" ;;
    *) echo "WHO ICD-10 fetch failed for $2 (HTTP $code)" >&2; exit 1 ;;
  esac
}

: > "$tmp/icd_pick.csv"
while read -r group cats; do
  [ -n "$group" ] || continue
  for c in $cats; do
    echo "$c,$group" >> "$tmp/icd_pick.csv"
    who_get 2019 "$c" "$tmp/icd_2019_$c.json"
  done
done <<<"$icd_groups"
for b in $icd_blocks; do who_get "${b%%:*}" "${b#*:}" "$tmp/icd_${b%%:*}_${b#*:}.json"; done

"$DUCKDB" :memory: -bail -c "
CREATE TABLE who AS
  SELECT ID AS code, regexp_replace(label, '^\S+\s+', '') AS title, isLeaf AS is_leaf,
         regexp_extract(filename, 'icd_(\d{4})_(.+)\.json', ['edition', 'parent']) AS f
  FROM read_json('$tmp/icd_*.json', filename = true,
                 columns = {'ID': 'VARCHAR', 'label': 'VARCHAR', 'isLeaf': 'BOOLEAN'});
CREATE TABLE pick AS
  FROM read_csv('$tmp/icd_pick.csv', header = false,
                columns = {'category': 'VARCHAR', 'scenario_group': 'VARCHAR'});
COPY (
  SELECT DISTINCT w.code AS icd10, p.category, w.title AS title_en, p.scenario_group,
         'WHO ICD-10 ' || w.f.edition AS source
  FROM pick p
  JOIN who w ON w.f.parent = p.category                                      -- children
             OR (w.code = p.category AND w.is_leaf
                 AND NOT EXISTS (FROM who c WHERE c.f.parent = p.category))  -- leaf category
  ORDER BY icd10
) TO '$OUT/ref_icd10.csv' (HEADER);"

echo "open data written to $OUT/"
