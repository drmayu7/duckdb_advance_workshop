-- Demo: gaps and islands (Module 3, before C8, facilitator only, ~10 min).
-- Made-up pharmacy refills, typed in the cell.
--
-- Run in the DuckDB UI from the bundle folder.

-- begin setup
-- Two patients' metformin refills. A refill picked up within 7 days of the
-- last supply running out continues the same course of treatment.
CREATE OR REPLACE TABLE refill AS
FROM (VALUES ('P1', DATE '2019-01-05', 30),
             ('P1', DATE '2019-02-06', 30),
             ('P1', DATE '2019-03-10', 30),
             ('P1', DATE '2019-06-20', 30),
             ('P1', DATE '2019-07-18', 30),
             ('P2', DATE '2019-02-01', 60),
             ('P2', DATE '2019-05-15', 30))
     AS t(patient, filled, days_supply);
-- end setup

-- 1. lag() looks one row back in the patient's own history: how many days
-- after the last supply ran out was this refill picked up?
SELECT *, filled + days_supply AS runs_out,
       filled - lag(runs_out) OVER (PARTITION BY patient ORDER BY filled) AS gap_days
FROM refill
ORDER BY patient, filled;

-- 2. Flag each refill that starts a new course (the first one, or a gap of
-- more than 7 days). A running sum of the flags numbers the courses: the
-- islands.
CREATE OR REPLACE TABLE refill_course AS
SELECT *,
       sum(new_course) OVER (PARTITION BY patient ORDER BY filled) AS course_no
FROM (SELECT *,
             CASE WHEN filled - lag(filled + days_supply) OVER w <= 7 THEN 0
                  ELSE 1 END AS new_course
      FROM refill
      WINDOW w AS (PARTITION BY patient ORDER BY filled));

-- 3. Look at the numbered refills, then GROUP BY the course number: one row
-- per island. first(... ORDER BY ...) picks a value from its first refill.
FROM refill_course ORDER BY patient, filled;

SELECT patient, course_no,
       min(filled) AS course_start,
       max(filled + days_supply) AS course_end,
       count(*) AS refills,
       first(days_supply ORDER BY filled) AS first_supply
FROM refill_course
GROUP BY ALL
ORDER BY patient, course_no;
