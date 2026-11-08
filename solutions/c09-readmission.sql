-- Reveal: C9, "30-day readmission" (cards/c09-readmission.md).
-- Run from the bundle folder, in your Work database, after C8 (or its Checkpoint).

-- Look first: how the three systems write the discharge status (AD04). Malay in
-- the old HIS, English after, and every case.
SELECT discharge_status, count(*) AS episodes
FROM episode
GROUP BY ALL
ORDER BY episodes DESC;

-- norm_status: letters only, upper case, then every known spelling to one of
-- four statuses. An unknown spelling gives NULL, so it shows up.
CREATE OR REPLACE MACRO status_key(s) AS regexp_replace(upper(s), '[^A-Z]', '', 'g');
CREATE OR REPLACE MACRO norm_status(s) AS
  CASE
    WHEN status_key(s) IN ('DISCHARGED', 'DISCAJ', 'BALIKRUMAH', 'HOME') THEN 'DISCHARGED'
    WHEN status_key(s) IN ('DIED', 'DEATH', 'EXPIRED', 'MATI', 'MENINGGALDUNIA') THEN 'DIED'
    WHEN status_key(s) IN ('TRANSFERRED', 'TRANSFER', 'TRANSFERREDOUT', 'PINDAH', 'DIPINDAHKAN', 'PINDAHHOSPITAL')
      THEN 'TRANSFERRED'
    WHEN status_key(s) IN ('AOR', 'ATOWNRISK', 'DISCHARGEATOWNRISK', 'ATASRISIKOSENDIRI', 'DISCAJATASRISIKOSENDIRI')
      THEN 'AOR'
  END;

-- Every spelling maps (want 0 rows).
SELECT discharge_status, count(*) AS episodes FROM episode WHERE norm_status(discharge_status) IS NULL GROUP BY ALL;

-- Core.
--   1. For every episode, the patient's next episode's start: lead() over ALL
--      the patient's episodes. Filtering to diabetes first would skip a
--      readmission for something else.
--   2. Index episodes: principal diagnosis in the diabetes group (E10-E14),
--      not ending in death (IS DISTINCT FROM: a missing status is not a death).
--   3. Readmitted: the next episode starts 1-30 days after the index ends.
CREATE OR REPLACE TABLE readmit_state AS
WITH followed AS (
  SELECT *, lead(episode_start) OVER (PARTITION BY patient_key ORDER BY episode_no) AS next_start
  FROM episode
),
idx AS (
  SELECT state, coalesce(date_diff('day', episode_end, next_start) BETWEEN 1 AND 30, false) AS readmitted
  FROM followed
  WHERE principal_dx IN (SELECT icd10 FROM read_csv('data/open/ref_icd10.csv') WHERE scenario_group = 'diabetes')
    AND norm_status(discharge_status) IS DISTINCT FROM 'DIED'
)
SELECT state,
       count(*) AS index_episodes,
       count(*) FILTER (WHERE readmitted) AS readmissions,
       round(100 * readmissions / index_episodes, 1) AS readmit_pct
FROM idx
GROUP BY state;

FROM readmit_state ORDER BY readmit_pct DESC, state;

-- What the status spellings would have done: testing discharge_status = 'DIED'
-- as written leaves the Malay and English deaths in as index episodes that can never be readmitted.
SELECT count(*) FILTER (WHERE discharge_status = 'DIED') AS died_as_written,
       count(*) FILTER (WHERE norm_status(discharge_status) = 'DIED') AS died
FROM episode
WHERE principal_dx IN (SELECT icd10 FROM read_csv('data/open/ref_icd10.csv') WHERE scenario_group = 'diabetes');

-- Stretch S1: diabetes as a secondary diagnosis too. secondary_dx is a text
-- list ('E11.9; I10') on the episode's first admission; string_split makes it
-- a list, and list_has_any tests it against the diabetes codes.
WITH diabetes AS (
  SELECT list(icd10) AS codes FROM read_csv('data/open/ref_icd10.csv') WHERE scenario_group = 'diabetes'
)
SELECT count(*) FILTER (WHERE e.principal_dx IN (SELECT unnest(codes) FROM diabetes)) AS principal_only,
       count(*) FILTER (WHERE e.principal_dx IN (SELECT unnest(codes) FROM diabetes)
                           OR list_has_any(string_split(a.secondary_dx, '; '), (SELECT codes FROM diabetes))) AS principal_or_secondary
FROM episode e
JOIN admission_clean a ON a.patient_key = e.patient_key AND a.admit_date = e.episode_start
WHERE norm_status(e.discharge_status) IS DISTINCT FROM 'DIED';

-- Stretch S2: readmission by age band and by length of stay.
WITH followed AS (
  SELECT *, coalesce(date_diff('day', episode_end,
                               lead(episode_start) OVER (PARTITION BY patient_key ORDER BY episode_no)) BETWEEN 1 AND 30,
                     false) AS readmitted
  FROM episode
)
SELECT CASE WHEN age < 50 THEN 'a. under 50' WHEN age < 65 THEN 'b. 50-64' WHEN age >= 65 THEN 'c. 65+' ELSE 'd. unknown' END AS age_band,
       CASE WHEN los_days < 3 THEN 'a. 0-2 days' WHEN los_days < 7 THEN 'b. 3-6 days' ELSE 'c. 7+ days' END AS los_band,
       count(*) AS index_episodes,
       round(100 * avg(readmitted::INTEGER), 1) AS readmit_pct
FROM followed
WHERE principal_dx IN (SELECT icd10 FROM read_csv('data/open/ref_icd10.csv') WHERE scenario_group = 'diabetes')
  AND norm_status(discharge_status) IS DISTINCT FROM 'DIED'
GROUP BY GROUPING SETS ((age_band), (los_band))
ORDER BY age_band NULLS LAST, los_band NULLS LAST;
