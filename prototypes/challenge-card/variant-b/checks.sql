-- PROTOTYPE. Variant B: self-grading check macros.
-- In the real thing these ship pre-loaded inside the Offline bundle's workshop.duckdb, so Participants
-- never paste them. They hold only expected *numbers* (counts + an md5 fingerprint), never the answer SQL.

CREATE OR REPLACE MACRO ch13_fp(id, flag) AS
    left(md5(string_agg(format('{}:{}', id, flag), ',' ORDER BY id)), 8);

CREATE OR REPLACE MACRO check_ch13_core() AS TABLE
WITH s AS (
    SELECT count(*)                AS n,
           count_if(readmit_30d)   AS r,
           ch13_fp(admission_id, readmit_30d) AS fp
    FROM ch13_readmit
)
SELECT '1 rows' AS "check",
       CASE WHEN n = 4440 THEN '✅ PASS' ELSE '❌ FAIL' END AS status,
       CASE WHEN n = 4440 THEN format('{} index admissions', n)
            WHEN n = 0    THEN 'ch13_readmit is still empty: write your query as CREATE OR REPLACE TABLE ch13_readmit AS ...'
            WHEN n = 4500 THEN format('{} rows, expected 4440. Patients who died are not index admissions: drop them, but only after LEAD has run (QUALIFY).', n)
            WHEN n > 4440 THEN format('{} rows, expected 4440. Too many: is something duplicating rows?', n)
            ELSE format('{} rows, expected 4440. Too few: did you filter with WHERE before the window ran, or drop admissions with no next admission?', n) END AS hint
FROM s
UNION ALL
SELECT '2 readmissions',
       CASE WHEN r = 606 THEN '✅ PASS' ELSE '❌ FAIL' END,
       CASE WHEN r = 606 THEN format('{} readmissions', r)
            WHEN r = 501 THEN format('{} flagged, expected 606. Count the 30 days from discharge_date, not admit_date.', r)
            ELSE format('{} flagged, expected 606. Is it 0–30 days inclusive, measured from this discharge to the NEXT admission (LEAD, not LAG)?', r) END
FROM s
UNION ALL
SELECT '3 fingerprint',
       CASE WHEN fp = '8a166ede' THEN '✅ PASS' ELSE '❌ FAIL' END,
       CASE WHEN fp = '8a166ede' THEN 'the right admissions are flagged'
            WHEN n = 4440 AND r = 606 THEN 'Counts match but different admissions are flagged. The flag belongs on the index (first) admission.'
            ELSE 'fix the checks above first' END
FROM s
ORDER BY "check";

CREATE OR REPLACE MACRO check_ch13_stretch() AS TABLE
WITH u AS (
    SELECT count_if(unplanned_30d) AS u, ch13_fp(admission_id, unplanned_30d) AS fp FROM ch13_readmit_unplanned
), st AS (
    SELECT count(*) AS n_states, sum(index_admissions) AS idx, first(state ORDER BY rate_pct DESC) AS top,
           max(rate_pct) AS top_rate
    FROM ch13_by_state
)
SELECT 'S1 unplanned' AS "check",
       CASE WHEN fp = '2628b773' THEN '✅ PASS' ELSE '❌ FAIL' END AS status,
       CASE WHEN fp = '2628b773' THEN format('{} unplanned readmissions', u)
            ELSE format('{} unplanned, expected 567. A readmission is planned when the NEXT admission is Z51.1.', u) END AS hint
FROM u
UNION ALL
SELECT 'S2 by state',
       CASE WHEN n_states = 16 AND idx = 4440 AND top = 'Sarawak' AND top_rate = 14.3 THEN '✅ PASS' ELSE '❌ FAIL' END,
       CASE WHEN n_states <> 16 THEN format('{} states, expected 16', n_states)
            WHEN idx <> 4440 THEN format('index admissions add up to {}, expected 4440', idx)
            WHEN top = 'Sarawak' AND top_rate = 14.3 THEN 'Sarawak is highest at 14.3%'
            ELSE format('top state is {} at {}%. Is the rate unplanned readmissions ÷ index admissions × 100, to 1 dp?', top, top_rate) END
FROM st;
