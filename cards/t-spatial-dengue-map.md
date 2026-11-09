---
id: t-spatial
title: Spatial: dengue by district
module: m4
timebox: 40 min
input: admission_clean, facility_clean, data/open/population_district.parquet, data/open/geo_district.geojson, data/open/ref_icd10.csv
output: dengue_district
---

# Extension track: Spatial: dengue by district

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 40 min · **Extension:** `spatial` · **Techniques:** a crosswalk table, `ST_Read()`, a polygon join, `COPY … (FORMAT gdal)`, `ST_Point()`, `ST_Contains()`

**Scenario.** The Director's second question asks for dengue **by district**, and wants a map. The admissions name the patient's **MoH health district**; DOSM's population and boundary polygons use **administrative districts**, and the two lists don't always agree (GE02). The team builds the crosswalk, computes the rate, and exports a map layer.

**Starts from:** the C5 and C6 Checkpoints (`facility_clean`, `admission_clean`), so you can do this track whatever state your earlier work is in.

**Input → output.** `admission_clean` (from C6), with DOSM district population and polygons from `data/open/` → **`dengue_district`**, one row per DOSM district (160), with these columns in this order, plus a map layer `dengue_district.geojson`:

`state`, `district`, `people`, `dengue_admissions`, `adm_per_100k`

## Start here: C5's macros

Did C5 from its Checkpoint, or in another Work database? Run this cell first (it is C5's solution, so it replaces yours if you have them):

<!-- begin macros -->
```sql
CREATE OR REPLACE MACRO state_key(s) AS regexp_replace(upper(s), '[^A-Z]', '', 'g');
CREATE OR REPLACE MACRO norm_state(s) AS
  CASE
    WHEN state_key(s) IN ('JOHOR', 'JOHORDARULTAKZIM', 'JHR') THEN 'JOHOR'
    WHEN state_key(s) IN ('KEDAH', 'KEDAHDARULAMAN', 'KDH') THEN 'KEDAH'
    WHEN state_key(s) IN ('KELANTAN', 'KELANTANDARULNAIM', 'KTN') THEN 'KELANTAN'
    WHEN state_key(s) IN ('MELAKA', 'MALACCA', 'MLK') THEN 'MELAKA'
    WHEN state_key(s) IN ('NEGERISEMBILAN', 'NSEMBILAN', 'NEGRISEMBILAN', 'NSN') THEN 'NEGERI SEMBILAN'
    WHEN state_key(s) IN ('PAHANG', 'PAHANGDARULMAKMUR', 'PHG') THEN 'PAHANG'
    WHEN state_key(s) IN ('PERAK', 'PERAKDARULRIDZUAN', 'PRK') THEN 'PERAK'
    WHEN state_key(s) IN ('PERLIS', 'PERLISINDERAKAYANGAN', 'PLS') THEN 'PERLIS'
    WHEN state_key(s) IN ('PULAUPINANG', 'PPINANG', 'PENANG', 'PNG') THEN 'PULAU PINANG'
    WHEN state_key(s) IN ('SABAH', 'SBH') THEN 'SABAH'
    WHEN state_key(s) IN ('SARAWAK', 'SWK') THEN 'SARAWAK'
    WHEN state_key(s) IN ('SELANGOR', 'SELANGORDARULEHSAN', 'SGR') THEN 'SELANGOR'
    WHEN state_key(s) IN ('TERENGGANU', 'TERENGGANUDARULIMAN', 'TRG') THEN 'TERENGGANU'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANKUALALUMPUR', 'WPKUALALUMPUR', 'KUALALUMPUR', 'WPKL')
      THEN 'WILAYAH PERSEKUTUAN KUALA LUMPUR'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANLABUAN', 'WPLABUAN', 'LABUAN') THEN 'WILAYAH PERSEKUTUAN LABUAN'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANPUTRAJAYA', 'WPPUTRAJAYA', 'PUTRAJAYA') THEN 'WILAYAH PERSEKUTUAN PUTRAJAYA'
  END;

-- norm_icd (DX01): upper case, letters and digits only, then a dot after the
-- third character and at most one character after it: e119, E11.9 and E11.90
-- all become E11.9; I10 stays I10.
CREATE OR REPLACE MACRO icd_key(code) AS regexp_replace(upper(code), '[^A-Z0-9]', '', 'g');
CREATE OR REPLACE MACRO norm_icd(code) AS
  CASE WHEN code IS NOT NULL THEN concat_ws('.', icd_key(code)[1:3], nullif(icd_key(code)[4:4], '')) END;
```
<!-- end macros -->

## Look first

Load the extension, and make every point `(x, y)` = (longitude, latitude):

```sql
LOAD spatial;
SET geometry_always_xy = true;
```

Which health districts have no DOSM district of the same name?

```sql
WITH dosm AS (
  SELECT DISTINCT norm_state(state) AS state, upper(district) AS district
  FROM 'data/open/population_district.parquet' WHERE date = DATE '2020-01-01'
)
SELECT a.state, a.district, count(*) AS admissions
FROM admission_clean a
WHERE a.district IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dosm d WHERE d.state = a.state AND d.district = a.district)
GROUP BY ALL
ORDER BY a.state, a.district;
```

## Definitions

- **The crosswalk (GE02):** a health district whose upper-cased name is a DOSM district of its state maps to it. The 10 that aren't map like this (several have both spellings in the data, `ULU LANGAT` and `HULU LANGAT`, `PERLIS` and `KANGAR`: both land in the one DOSM district):
  - `KANGAR` → `PERLIS` (Perlis is one DOSM district)
  - `MERADONG` → `MARADONG`
  - `HULU LANGAT` → `ULU LANGAT`, `HULU SELANGOR` → `ULU SELANGOR`
  - `CHERAS`, `KEPONG`, `LEMBAH PANTAI`, `TITIWANGSA` → `W.P. KUALA LUMPUR`
  - `LABUAN` → `W.P. LABUAN`, `PUTRAJAYA` → `W.P. PUTRAJAYA`
- **Rows:** every DOSM district in `population_district.parquet` for `date = 2020-01-01`. **`state`** = `norm_state(state)`; **`district`** as DOSM writes it (`Ulu Langat`), which is also its name in the polygons.
- **`people`**: DOSM's 2020 population (`sex = 'both'`, `age = 'overall'`, `ethnicity = 'overall'`, in thousands) × 1000, `round(…)::BIGINT`. District rates use 2020 population for every year.
- **`dengue_admissions`**: admissions in `admission_clean` whose `principal_dx` is in `ref_icd10`'s `scenario_group = 'dengue'` (so A90/A91 too), 2018–2020, by the patient's district. 0 for a district with none. An admission with no district can't be placed and is left out.
- **`adm_per_100k`**: per 100,000 people **per year**: `round(100000 * dengue_admissions / 3 / people, 1)`.
- **Tie-break:** none needed: there is one row per DOSM district, and district names are unique.

## Example row

<!-- begin example-row -->
| state | district | people | dengue_admissions | adm_per_100k |
|---|---|---|---|---|
| SELANGOR | Ulu Langat | 1400500 | 140 | 3.3 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Put the 10 crosswalk rows in a table (`FROM (VALUES (…), …) t(state, health_district, dosm_district)`). Count dengue admissions by DOSM district (`coalesce` the crosswalk's name with the health district's own), then join them to DOSM's districts and population. Check nothing is lost: the districts add up to every dengue admission with a district. Run the Self-check. Then join to the polygons, `FROM ST_Read('data/open/geo_district.geojson')`, `USING (district)` (all 160 should join), and export the map: `COPY (SELECT d.*, g.geom FROM …) TO 'dengue_district.geojson' (FORMAT gdal, DRIVER 'GeoJSON');`. Open it in QGIS, or drag it onto geojson.io. |
| S1 | Point in polygon: which DOSM district is each hospital really in? `ST_Contains(g.geom, ST_Point(f.longitude, f.latitude))`. Compare with the hospital's health district. One hospital lands in the wrong **state**: is it the polygon or the hospital's coordinates? |
| S2 | The hospital nearest each district's centre, in km: `ST_Distance_Sphere(ST_Centroid(g.geom), ST_Point(f.longitude, f.latitude)) / 1000`. Which districts are furthest from any hospital? (Without `geometry_always_xy`, KL to Penang comes out 158 km instead of 294.) |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM dengue_district
       EXCEPT ALL SELECT * FROM 'expected/dengue_district.parquet')
      UNION ALL
      (SELECT * FROM 'expected/dengue_district.parquet'
       EXCEPT ALL SELECT * FROM dengue_district));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM dengue_district
                                   EXCEPT ALL SELECT * FROM 'expected/dengue_district.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/dengue_district.parquet'
                                      EXCEPT ALL SELECT * FROM dengue_district)))
ORDER BY district, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. W.P. Kuala Lumpur, Ulu Langat or Perlis at 0? A crosswalk row is missing or misspelt. Every rate about 3 times too high? You forgot `/ 3`: it is per year. A few districts high or low? You counted only `A97.%` and missed the legacy A90/A91 codes.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE dengue_district AS FROM 'expected/dengue_district.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/t-spatial-dengue-map.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
