-- Demo: combining feeds that disagree (Module 1, before C3, facilitator only, ~10 min).
-- Real open data: the MoH facility list (JSON) and hospital bed counts (CSV).
--
-- Run in the DuckDB UI from the bundle folder.

-- 1. JSON and Parquet are read like CSV, and DESCRIBE shows what each file holds
-- before you combine them. The facility list names its columns in Malay.
DESCRIBE FROM read_json('data/open/facilities.json');
DESCRIBE FROM read_parquet('data/open/population_state.parquet');

-- 2. UNION ALL stacks by position: the second query's columns land under the
-- first query's names, whatever they mean. Here the codes end up as names.
SELECT hospital AS name, state FROM 'data/open/bed_utilisation.csv'
UNION ALL
SELECT KOD_FASILITI, NAMA FROM read_json('data/open/facilities.json')
LIMIT 3 OFFSET 147;

-- 3. UNION ALL BY NAME matches columns by name, in any order, and fills a
-- column that one side doesn't have with NULL.
SELECT 'beds_csv' AS source, hospital AS name, state, beds_nonicu AS beds
FROM 'data/open/bed_utilisation.csv'
WHERE hospital ILIKE '%raub%'
UNION ALL BY NAME
SELECT 'facility_json' AS source, NEGERI AS state, NAMA AS name, KOD_FASILITI AS facility_code
FROM read_json('data/open/facilities.json')
WHERE KATEGORI_FASILITI = 'HOSPITAL' AND NAMA ILIKE '%raub%';

-- 4. COLUMNS(* EXCLUDE (...)) turns every remaining column into text in one line,
-- so feeds that type the same column differently still stack.
SELECT COLUMNS(* EXCLUDE (PROGRAM_GROUP, BANDAR, URBAN_RURAL))::VARCHAR
FROM read_json('data/open/facilities.json')
LIMIT 3;
