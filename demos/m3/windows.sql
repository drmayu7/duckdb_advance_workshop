-- Demo: window functions (Module 3, before C7, facilitator only, ~8 min).
-- MOH bed utilisation (real open data): the beds of each public hospital.
-- A window function adds a value computed over a group of rows to every row,
-- without collapsing the rows the way GROUP BY does.
--
-- Run in the DuckDB UI from the bundle folder.

-- 1. GROUP BY first, then a window over its result: each state's beds, and
-- its share of the country's. sum(sum(...)) OVER () adds up every state's sum.
SELECT state, sum(beds_nonicu) AS beds,
       round(100 * beds / sum(sum(beds_nonicu)) OVER (), 1) AS national_pct
FROM 'data/open/bed_utilisation.csv'
GROUP BY ALL
ORDER BY beds DESC;

-- 2. PARTITION BY: every hospital keeps its row and gets its own state's
-- total beside it, so its share of the state is one division away.
SELECT state, hospital, beds_nonicu AS beds,
       sum(beds_nonicu) OVER (PARTITION BY state) AS state_beds,
       round(100 * beds / state_beds, 1) AS state_pct
FROM 'data/open/bed_utilisation.csv'
WHERE state = 'Pahang' AND beds_nonicu > 0
ORDER BY beds DESC;

-- 3. rank() numbers the hospitals within each state, biggest first; ties
-- share a rank. QUALIFY keeps the two biggest in every state.
SELECT state, hospital, beds_nonicu AS beds,
       rank() OVER (PARTITION BY state ORDER BY beds_nonicu DESC) AS state_rank
FROM 'data/open/bed_utilisation.csv'
WHERE beds_nonicu > 0
QUALIFY state_rank <= 2
ORDER BY state, state_rank;

-- 4. A running total: ORDER BY inside OVER sums from the first row to this
-- one. How many hospitals hold half of Pahang's beds?
SELECT hospital, beds_nonicu AS beds,
       sum(beds_nonicu) OVER (ORDER BY beds_nonicu DESC, hospital) AS running_beds,
       round(100 * running_beds / sum(beds_nonicu) OVER (), 1) AS running_pct
FROM 'data/open/bed_utilisation.csv'
WHERE state = 'Pahang' AND beds_nonicu > 0
ORDER BY beds DESC;
