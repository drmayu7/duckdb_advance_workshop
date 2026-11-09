-- Demo: Series 1 SQL in four queries (Series 1 refresher, facilitator only, ~10 min).
-- Real open data: MoH hospital bed counts and DOSM state population.
--
-- Run in the DuckDB UI from the bundle folder. Each step is one Series 1 idea;
-- the Warm-up Challenge uses the same ideas on the 2017 admissions.

-- 1. FROM a file, WHERE, ORDER BY, LIMIT: the biggest hospitals by non-ICU beds.
SELECT hospital, state, beds_nonicu
FROM 'data/open/bed_utilisation.csv'
WHERE beds_nonicu > 0
ORDER BY beds_nonicu DESC
LIMIT 5;

-- 2. GROUP BY and HAVING: beds per state, only states with more than 2,000 beds.
-- WHERE filters rows before grouping; HAVING filters the groups after.
SELECT state, count(*) AS hospitals, sum(beds_nonicu) AS beds
FROM 'data/open/bed_utilisation.csv'
GROUP BY state
HAVING sum(beds_nonicu) > 2000
ORDER BY beds DESC;

-- 3. A JOIN inside a CTE: beds per 10,000 people in 2020. DOSM counts people
-- in thousands, and the bed file writes states the same way, so they join.
WITH beds AS (
  SELECT state, sum(beds_nonicu) AS beds
  FROM 'data/open/bed_utilisation.csv'
  GROUP BY state
),
people AS (
  SELECT state, population * 1000 AS population
  FROM 'data/open/population_state.parquet'
  WHERE date = DATE '2020-01-01'
    AND sex = 'both' AND age = 'overall' AND ethnicity = 'overall'
)
SELECT b.state, b.beds, p.population,
       round(b.beds / p.population * 10000, 1) AS beds_per_10k
FROM beds AS b
JOIN people AS p ON p.state = b.state
ORDER BY beds_per_10k DESC;

-- 4. A subquery: hospitals with more beds than the average hospital that has any.
SELECT hospital, state, beds_nonicu
FROM 'data/open/bed_utilisation.csv'
WHERE beds_nonicu > (SELECT avg(beds_nonicu)
                     FROM 'data/open/bed_utilisation.csv'
                     WHERE beds_nonicu > 0)
ORDER BY beds_nonicu DESC;
