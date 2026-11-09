-- The facilitator's lunch-time diff (#10): each team's summary Parquet against
-- the true 2021 figures. Run from the repo root (or any folder that holds
-- capstone_truth/), in any DuckDB session:
--
--   .read capstone_truth/check.sql
--   FROM check_readmit('team_A/readmit_2021.parquet');        -- Angle A
--   FROM check_dengue('team_B/dengue_2021.parquet');          -- Angle B
--   FROM check_load('team_C/hospital_load_2021.parquet');     -- Angle C
--
-- Each gives one line: "matches", or how many state (or hospital) rows differ.
-- It reads the 2021 columns by the names capstone/brief.md gives, casts them to
-- the truth's types, and ignores the earlier-year column. To see the rows
-- themselves, run the two EXCEPT ALL halves of the macro on their own.

-- "matches", "1 state row differs" or "N state rows differ".
CREATE OR REPLACE MACRO verdict(differing, n, what) AS
  CASE WHEN differing = 0 THEN 'matches'
       WHEN n = 1 THEN '1 ' || what || ' row differs'
       ELSE n || ' ' || what || ' rows differ' END;

CREATE OR REPLACE MACRO check_readmit(path) AS TABLE
WITH team AS (
  SELECT state::VARCHAR AS state, index_episodes::BIGINT AS index_episodes,
         readmissions::BIGINT AS readmissions, readmit_pct::DOUBLE AS readmit_pct
  FROM read_parquet(path)
),
truth AS (FROM 'capstone_truth/readmit_2021.parquet'),
differ AS ((FROM team EXCEPT ALL FROM truth) UNION ALL (FROM truth EXCEPT ALL FROM team))
SELECT verdict(count(*), count(DISTINCT state), 'state') AS result
FROM differ;

CREATE OR REPLACE MACRO check_dengue(path) AS TABLE
WITH team AS (
  SELECT state::VARCHAR AS state, dengue_admissions::BIGINT AS dengue_admissions,
         adm_per_100k::DOUBLE AS adm_per_100k
  FROM read_parquet(path)
),
truth AS (FROM 'capstone_truth/dengue_2021.parquet'),
differ AS ((FROM team EXCEPT ALL FROM truth) UNION ALL (FROM truth EXCEPT ALL FROM team))
SELECT verdict(count(*), count(DISTINCT state), 'state') AS result
FROM differ;

CREATE OR REPLACE MACRO check_load(path) AS TABLE
WITH team AS (
  SELECT state::VARCHAR AS state, facility_code::VARCHAR AS facility_code, facility_name::VARCHAR AS facility_name,
         admissions::BIGINT AS admissions, bed_days::BIGINT AS bed_days,
         state_share_pct::DOUBLE AS state_share_pct, state_rank::BIGINT AS state_rank
  FROM read_parquet(path)
),
truth AS (FROM 'capstone_truth/hospital_load_2021.parquet'),
differ AS ((FROM team EXCEPT ALL FROM truth) UNION ALL (FROM truth EXCEPT ALL FROM team))
SELECT verdict(count(*), count(DISTINCT facility_code), 'hospital') AS result
FROM differ;
