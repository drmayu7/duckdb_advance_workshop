-- PROTOTYPE. Canonical solution for "Challenge 1.3: Who comes back within 30 days?"
-- In every variant this is the reveal. It is also what the Self-check expectations are computed from.

-- Core ------------------------------------------------------------------------
CREATE OR REPLACE TABLE ch13_readmit AS
SELECT
    admission_id,
    patient_id,
    discharge_date,
    lead(admit_date) OVER w                           AS next_admit_date,
    next_admit_date - discharge_date                  AS days_to_readmit,
    coalesce(days_to_readmit BETWEEN 0 AND 30, false) AS readmit_30d
FROM admissions
WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date, admission_id)
QUALIFY discharge_status <> 'Died'          -- filter AFTER the window, so neighbours are not lost
ORDER BY admission_id;

-- Stretch S1: planned readmissions (chemotherapy Z51.1) do not count ------------
CREATE OR REPLACE TABLE ch13_readmit_unplanned AS
SELECT
    admission_id,
    patient_id,
    discharge_date,
    lead(admit_date) OVER w                           AS next_admit_date,
    lead(primary_dx) OVER w                           AS next_dx,
    next_admit_date - discharge_date                  AS days_to_readmit,
    coalesce(days_to_readmit BETWEEN 0 AND 30, false) AS readmit_30d,
    readmit_30d AND next_dx <> 'Z51.1'                AS unplanned_30d
FROM admissions
WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date, admission_id)
QUALIFY discharge_status <> 'Died'
ORDER BY admission_id;

-- Stretch S2: rate by state ----------------------------------------------------
CREATE OR REPLACE TABLE ch13_by_state AS
SELECT
    a.state,
    count(*)                                              AS index_admissions,
    count_if(u.unplanned_30d)                             AS unplanned_readmissions,
    round(100.0 * count_if(u.unplanned_30d) / count(*), 1) AS rate_pct
FROM ch13_readmit_unplanned u
JOIN admissions a USING (admission_id)
GROUP BY a.state
ORDER BY rate_pct DESC, state;
