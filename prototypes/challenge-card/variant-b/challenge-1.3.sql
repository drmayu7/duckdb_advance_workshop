-- ============================================================================
-- PROTOTYPE, Variant B: "Self-grading SQL file".
-- The card IS a .sql file. Prose lives in comments; each "-- %% CELL" block is
-- pasted into its own DuckDB UI cell. You don't compare numbers by eye: a
-- pre-loaded check macro grades you and tells you what to fix.
-- The solution is NOT in this file: it lives in solutions/challenge-1.3.sql.
-- ============================================================================
--
-- CHALLENGE 1.3: Who comes back within 30 days?
-- Module: Advanced SQL for wrangling (Day 1 AM) | 35 min | lead(), WINDOW, QUALIFY
--
-- SCENARIO: The state health department wants the 30-day readmission rate.
-- (Synthetic data: no clinical meaning.)
--
-- RULES
--   index admission    = discharge_status <> 'Died'
--   next admission     = same patient, next by admit_date then admission_id
--   30-day readmission = next admit_date is 0-30 days (inclusive) after discharge_date
--
-- ---------------------------------------------------------------------------
-- %% CELL 1: see what your answer table must look like (it starts empty)
DESCRIBE ch13_readmit;

-- ---------------------------------------------------------------------------
-- %% CELL 2: CORE. One row per index admission. readmit_30d is never NULL.
CREATE OR REPLACE TABLE ch13_readmit AS
-- your query here
;

-- ---------------------------------------------------------------------------
-- %% CELL 3: SELF-CHECK. Run after every attempt. Read the hint column.
FROM check_ch13_core();

-- ---------------------------------------------------------------------------
-- %% CELL 4: STRETCH S1. Planned readmissions (next admission is Z51.1, chemo)
-- don't count. Add next_dx and unplanned_30d.  DESCRIBE ch13_readmit_unplanned;
CREATE OR REPLACE TABLE ch13_readmit_unplanned AS
-- your query here
;

-- %% CELL 5: STRETCH S2. Unplanned rate per state, to 1 dp, highest first.
CREATE OR REPLACE TABLE ch13_by_state AS
-- your query here
;

-- %% CELL 6: SELF-CHECK (Stretch)
FROM check_ch13_stretch();
