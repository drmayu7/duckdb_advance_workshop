-- Demo: looking forward with lead() (Module 3, before C9, facilitator only, ~8 min).
-- Made-up emergency department visits, typed in the cell. The question is
-- the ED's own: who sent home came back within 3 days?
--
-- Run in the DuckDB UI from the bundle folder.

-- begin setup
CREATE OR REPLACE TABLE ed_visit AS
FROM (VALUES ('P1', DATE '2020-03-01', 'Balik rumah'),
             ('P1', DATE '2020-03-03', 'Warded'),
             ('P2', DATE '2020-03-02', 'Home'),
             ('P2', DATE '2020-03-20', 'home '),
             ('P3', DATE '2020-03-05', 'Meninggal'),
             ('P4', DATE '2020-03-06', 'Discaj'),
             ('P4', DATE '2020-03-08', 'Ditahan wad'))
     AS t(patient, visit_date, outcome);
-- end setup

-- 1. lead() looks one row forward: each visit with the patient's next one.
-- A column alias can be used again later in the same SELECT.
SELECT *,
       lead(visit_date) OVER (PARTITION BY patient ORDER BY visit_date) AS next_visit,
       next_visit - visit_date AS days_to_next
FROM ed_visit
ORDER BY patient, visit_date;

-- 2. One outcome, many spellings: a macro maps them, once.
CREATE OR REPLACE MACRO norm_outcome(s) AS
  CASE WHEN lower(trim(s)) IN ('home', 'balik rumah', 'discaj') THEN 'HOME'
       WHEN lower(trim(s)) IN ('warded', 'ditahan wad') THEN 'WARDED'
       WHEN lower(trim(s)) IN ('died', 'meninggal') THEN 'DIED'
  END;

SELECT outcome, norm_outcome(outcome) AS norm FROM ed_visit;

-- 3. Count with FILTER: visits sent home, and those back within 3 days. A
-- patient who died can't come back, so the outcome decides who counts.
SELECT count(*) FILTER (WHERE home) AS sent_home,
       count(*) FILTER (WHERE home AND days_to_next <= 3) AS back_in_3_days,
       round(100 * back_in_3_days / sent_home, 1) AS return_pct
FROM (SELECT norm_outcome(outcome) = 'HOME' AS home,
             lead(visit_date) OVER (PARTITION BY patient ORDER BY visit_date)
               - visit_date AS days_to_next
      FROM ed_visit);
