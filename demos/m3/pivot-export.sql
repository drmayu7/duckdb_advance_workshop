-- Demo: UNPIVOT, PIVOT and export (Module 3, before C10, facilitator only, ~10 min).
-- MOH bed utilisation and DOSM state population (real open data).
--
-- Run in the DuckDB UI from the bundle folder. Step 4 writes files next to
-- the Work database.

-- 1. UNPIVOT turns columns into rows: the bed file has one column per kind
-- of bed. COLUMNS(* EXCLUDE ...) picks every column but the ones named.
CREATE OR REPLACE TABLE beds_long AS
UNPIVOT (SELECT state, hospital, beds_nonicu, beds_icu, vent
         FROM 'data/open/bed_utilisation.csv')
ON COLUMNS(* EXCLUDE (state, hospital))
INTO NAME kind VALUE beds;

FROM beds_long ORDER BY hospital, kind LIMIT 6;

-- 2. Long is easy to aggregate: one GROUP BY covers every kind of bed.
SELECT kind, sum(beds)::INTEGER AS beds, count(*) FILTER (WHERE beds > 0) AS hospitals
FROM beds_long
GROUP BY ALL
ORDER BY beds DESC;

-- 3. PIVOT turns rows into columns: DOSM's population is one row per state
-- and year; the summary wants one column per year.
CREATE OR REPLACE TABLE population_by_year AS
PIVOT (SELECT state, year(date) AS year, population
       FROM 'data/open/population_state.parquet'
       WHERE sex = 'both' AND age = 'overall'
         AND ethnicity = 'overall'
         AND year(date) BETWEEN 2018 AND 2021)
ON year
USING first(population)
GROUP BY state;

FROM population_by_year ORDER BY state;

-- 4. Export: COPY writes a table to Parquet, CSV, or Excel with the excel
-- extension (in your bundle). Read one back to check it.
COPY population_by_year TO 'population_by_year.parquet' (FORMAT parquet);
COPY population_by_year TO 'population_by_year.csv' (HEADER true);
LOAD excel;
COPY population_by_year TO 'population_by_year.xlsx' (FORMAT xlsx, HEADER true);

FROM read_xlsx('population_by_year.xlsx') LIMIT 3;
