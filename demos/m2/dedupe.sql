-- Demo: removing duplicates (Module 2, before C6, facilitator only, ~10 min).
-- Made-up bed returns, typed in the cell; the hospital names are real.
--
-- Run in the DuckDB UI from the bundle folder.

-- begin setup
-- Three hospitals report their beds. One return was sent twice (an exact
-- copy), and one was corrected later (a newer version).
CREATE OR REPLACE TABLE bed_return AS
FROM (VALUES ('Hospital Raub',     DATE '2019-04-01', 120, TIMESTAMP '2019-04-02 09:00'),
             ('Hospital Raub',     DATE '2019-04-01', 120, TIMESTAMP '2019-04-02 09:00'),
             ('Hospital Bentong',  DATE '2019-04-01',  80, TIMESTAMP '2019-04-02 10:00'),
             ('Hospital Bentong',  DATE '2019-04-01',  86, TIMESTAMP '2019-04-05 16:30'),
             ('Hospital Temerloh', DATE '2019-04-01', 410, TIMESTAMP '2019-04-02 11:15'))
     AS t(hospital, return_date, beds, sent_at);
-- end setup

-- 1. DISTINCT removes exact copies only: the Bentong correction stays twice.
SELECT DISTINCT * FROM bed_return ORDER BY hospital, sent_at;

-- 2. A window function numbers the rows within each group, newest first,
-- without collapsing them like GROUP BY would.
SELECT *, row_number() OVER (PARTITION BY hospital, return_date ORDER BY sent_at DESC) AS version
FROM bed_return
ORDER BY hospital, version;

-- 3. QUALIFY filters on a window function, as HAVING does on an aggregate:
-- one row per hospital and date, the latest.
CREATE OR REPLACE TABLE bed_return_clean AS
SELECT *
FROM bed_return
QUALIFY row_number() OVER (PARTITION BY hospital, return_date ORDER BY sent_at DESC) = 1;

FROM bed_return_clean ORDER BY hospital;

-- 4. Prove it: EXCEPT ALL keeps every copy, so it shows exactly what was removed.
SELECT * FROM bed_return EXCEPT ALL SELECT * FROM bed_return_clean;
