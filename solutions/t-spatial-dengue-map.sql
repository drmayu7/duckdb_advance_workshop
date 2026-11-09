-- Reveal: Extension track "Spatial: dengue by district" (cards/t-spatial-dengue-map.md).
-- Run from the bundle folder, in your Work database, after C5 and C6 (or their Checkpoints).

-- C5's macros, in case C5 was done from its Checkpoint (which loads the table only).
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

-- spatial is a core extension in your bundle; LOAD it so ST_ functions are there.
-- geometry_always_xy: points are always (x, y) = (longitude, latitude). Without it,
-- ST_Distance_Sphere and the GeoJSON export read EPSG:4326 as (latitude, longitude).
LOAD spatial;
SET geometry_always_xy = true;

-- Look first (GE02): admissions name the patient's MoH health district; DOSM's
-- population and polygons use administrative districts. Which names don't match?
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

-- Core, step 1: the crosswalk for the 10 names that differ. Every other health
-- district has the DOSM name, once upper-cased.
CREATE OR REPLACE TABLE district_crosswalk AS
FROM (VALUES
  ('PERLIS', 'KANGAR', 'PERLIS'),
  ('SARAWAK', 'MERADONG', 'MARADONG'),
  ('SELANGOR', 'HULU LANGAT', 'ULU LANGAT'),
  ('SELANGOR', 'HULU SELANGOR', 'ULU SELANGOR'),
  ('WILAYAH PERSEKUTUAN KUALA LUMPUR', 'CHERAS', 'W.P. KUALA LUMPUR'),
  ('WILAYAH PERSEKUTUAN KUALA LUMPUR', 'KEPONG', 'W.P. KUALA LUMPUR'),
  ('WILAYAH PERSEKUTUAN KUALA LUMPUR', 'LEMBAH PANTAI', 'W.P. KUALA LUMPUR'),
  ('WILAYAH PERSEKUTUAN KUALA LUMPUR', 'TITIWANGSA', 'W.P. KUALA LUMPUR'),
  ('WILAYAH PERSEKUTUAN LABUAN', 'LABUAN', 'W.P. LABUAN'),
  ('WILAYAH PERSEKUTUAN PUTRAJAYA', 'PUTRAJAYA', 'W.P. PUTRAJAYA')
) t(state, health_district, dosm_district);

-- Step 2: dengue admissions (scenario_group 'dengue', so A90/A91 too) by DOSM
-- district, per 100k people per year: three years over the 2020 population.
-- Every DOSM district gets a row, 0 when it has no admissions. An admission
-- with no district can't be placed, so it is left out.
CREATE OR REPLACE TABLE dengue_district AS
WITH dosm AS (
  SELECT norm_state(state) AS state, district, round(population * 1000)::BIGINT AS people
  FROM 'data/open/population_district.parquet'
  WHERE date = DATE '2020-01-01' AND sex = 'both' AND age = 'overall' AND ethnicity = 'overall'
),
admitted AS (
  SELECT a.state, coalesce(g.dosm_district, a.district) AS dosm_district, count(*) AS admissions
  FROM admission_clean a
  JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = a.principal_dx
  LEFT JOIN district_crosswalk g ON g.state = a.state AND g.health_district = a.district
  WHERE i.scenario_group = 'dengue' AND a.district IS NOT NULL
  GROUP BY ALL
)
SELECT d.state, d.district, d.people,
       coalesce(a.admissions, 0) AS dengue_admissions,
       round(100000 * coalesce(a.admissions, 0) / 3 / d.people, 1) AS adm_per_100k
FROM dosm d
LEFT JOIN admitted a ON a.state = d.state AND a.dosm_district = upper(d.district);

-- Nothing lost: the districts add up to every placed dengue admission.
SELECT sum(dengue_admissions) AS in_districts,
       (SELECT count(*) FROM admission_clean a JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = a.principal_dx
        WHERE i.scenario_group = 'dengue' AND a.district IS NOT NULL) AS placed
FROM dengue_district;

FROM dengue_district ORDER BY adm_per_100k DESC LIMIT 10;

-- Step 3: the polygons. ST_Read opens the GeoJSON as a table with a geom column;
-- DOSM names its districts the same way in both files, so they join on the name.
SELECT count(*) AS districts_with_polygon
FROM dengue_district d JOIN ST_Read('data/open/geo_district.geojson') g USING (district);

-- Export a map layer: GeoJSON opens in QGIS, or drag it onto https://geojson.io.
COPY (
  SELECT d.*, g.geom
  FROM dengue_district d JOIN ST_Read('data/open/geo_district.geojson') g USING (district)
) TO 'dengue_district.geojson' (FORMAT gdal, DRIVER 'GeoJSON');
SELECT count(*) AS features FROM ST_Read('dengue_district.geojson');

-- Stretch S1: point in polygon. Which DOSM district is each hospital really in?
-- ST_Point takes (x, y), so (longitude, latitude). Compare with its health district:
-- most differences are GE02 names, but Hospital Tuanku Fauziah (Kangar, Perlis) lands
-- in Kinta, Perak. Its coordinates in the MoH list are wrong, not the polygon.
SELECT f.facility_name, f.district AS health_district, g.district AS dosm_district
FROM facility_clean f
JOIN ST_Read('data/open/geo_district.geojson') g ON ST_Contains(g.geom, ST_Point(f.longitude, f.latitude))
WHERE upper(g.district) <> f.district
ORDER BY f.state, f.facility_name;

-- Stretch S2: the hospital nearest each district's centre, in km. This relies on
-- geometry_always_xy (set at the top): without it, KL to Penang comes out 158 km, not 294.
SELECT g.district, f.facility_name,
       round(ST_Distance_Sphere(ST_Centroid(g.geom), ST_Point(f.longitude, f.latitude)) / 1000, 1) AS km
FROM ST_Read('data/open/geo_district.geojson') g, facility_clean f
QUALIFY row_number() OVER (PARTITION BY g.district ORDER BY km, f.facility_code) = 1
ORDER BY km DESC
LIMIT 10;
