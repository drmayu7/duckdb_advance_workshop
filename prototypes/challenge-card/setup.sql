-- PROTOTYPE, wipe me. Throwaway data for the Challenge-card prototype (wayfinder ticket #5).
-- Not the real MyHDW-like dataset design (that is ticket #7). Synthetic, ~4k admissions.
-- Deterministic arithmetic only (no random(), no hash()), so the numbers are the same on 1.5.x and 2.0.x.

CREATE OR REPLACE TABLE admissions AS
WITH patients AS (
    SELECT range AS pid,
           1 + ((range * 7919) % 5)           AS n_adm,
           ((range * 104729) % 16)            AS state_ix,
           ((range * 1299709) % 100)          AS profile          -- 0-9 oncology, 10-29 chronic, rest general
    FROM range(1, 1501)
),
adm AS (
    SELECT pid, n_adm, state_ix, profile, unnest(generate_series(1, n_adm)) AS k
    FROM patients
),
rnd AS (
    SELECT *,
           ((pid * 31 + k * 17) * 2654435761) % 1000 AS r1,
           ((pid * 13 + k * 101) * 40503)     % 1000 AS r2
    FROM adm
),
steps AS (
    SELECT *,
           CASE WHEN k = 1 THEN (r1 % 180)
                WHEN r1 < 200 THEN r1 % 31                       -- comes back within 0-30 days
                WHEN r1 < 260 THEN 31 + r1 % 5                   -- near miss: 31-35 days
                ELSE 36 + r1 % 120 END                           AS gap_days,
           r2 % 12                                               AS los
    FROM rnd
),
dated AS (
    SELECT *,
           DATE '2024-01-01'
             + CAST(sum(gap_days + los) OVER (PARTITION BY pid ORDER BY k) - los AS INTEGER) AS admit_date
    FROM steps
)
SELECT
    CAST(row_number() OVER (ORDER BY admit_date, pid, k) AS INTEGER)              AS admission_id,
    printf('P%06d', pid)                                                       AS patient_id,
    ['Johor','Kedah','Kelantan','Melaka','Negeri Sembilan','Pahang','Perak','Perlis',
     'Pulau Pinang','Sabah','Sarawak','Selangor','Terengganu','W.P. Kuala Lumpur',
     'W.P. Labuan','W.P. Putrajaya'][state_ix + 1]                             AS state,
    printf('H%02d%02d', state_ix + 1, 1 + (pid % 3))                           AS facility_code,
    admit_date,
    admit_date + CAST(los AS INTEGER)                                          AS discharge_date,
    CASE WHEN profile < 10 AND k > 1 AND r2 % 3 <> 0 THEN 'Z51.1'               -- planned chemotherapy session
         WHEN profile < 10                     THEN 'C50.9'
         WHEN profile < 20                     THEN ['E11.9','N18.5','I50.9'][1 + r2 % 3]
         WHEN profile < 30                     THEN ['J44.1','I10'][1 + r2 % 2]
         ELSE ['J18.9','A90','K35.8','O80','S72.0','A09'][1 + r2 % 6] END      AS primary_dx,
    CASE WHEN k = n_adm AND r1 % 25 = 0 THEN 'Died'
         WHEN r2 % 40 = 0                THEN 'Transferred'
         ELSE 'Discharged' END                                                  AS discharge_status
FROM dated;
