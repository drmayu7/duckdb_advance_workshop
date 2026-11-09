-- Live demo: 30 million admissions on S3 (Module 3, facilitator only, ~15 min).
-- Synthetic data, not real hospital performance.
--
-- Answers the State Health Brief's hospital-load question at national scale:
-- the big data stays in the bucket, the clean hospital list stays local, and
-- only the answer comes home. Participants watch. Steps 1 and 4 need AWS
-- access of your own to try after the workshop: see the guide's "Reading a
-- private bucket" section, or point the paths at a local large/ folder.
--
-- Fallback if the network fails: a phone hotspot, skipping step 3b, then the
-- backup slides captured in the dry run. Bytes fetched, measured on 9 Nov:
-- step 1 0.5 MiB, step 3a 7 MiB, step 3b 414 MiB, step 4 55 MiB.

-- begin setup
-- Before the session, on the facilitator laptop (online). Refresh the AWS SSO
-- login that morning, in a terminal: aws sso login --profile naufal
INSTALL httpfs;
INSTALL aws;
CREATE OR REPLACE SECRET demo (TYPE s3, PROVIDER credential_chain, CHAIN 'sso',
                               PROFILE 'naufal', REGION 'ap-southeast-5');
-- The default (true) caches file contents, so a repeated query fetches ~1 KB
-- and the bytes comparison in step 3 means nothing.
SET enable_external_file_cache = false;
-- storage = 'memory': the CLI and UI default (shell_log_storage) cannot be truncated.
CALL enable_logging('HTTP', storage = 'memory');
-- end setup

-- 1. One secret, no keys in the SQL, no download. The count comes from the
-- Parquet footers alone.
SELECT count(*) AS admissions FROM 's3://duckdb-series2-2026/large/admission/*/*.parquet';

-- Which credential did DuckDB pick for this path?
FROM which_secret('s3://duckdb-series2-2026/large/x', 's3');

-- 2. Hive partitioning: `year` is not in the files. DuckDB reads it from the
-- folder names (year=2018 ... year=2021), with no flag needed.
DESCRIBE FROM 's3://duckdb-series2-2026/large/admission/*/*.parquet';

-- 3. Pruning, measured. Bytes fetched are in the HTTP log; clear it, run one
-- query, then read it.
CALL truncate_duckdb_logs();

-- 3a. Two columns, one year: 4 of the 16 files, one column chunk each.
SELECT facility_code, count(*) AS admissions
FROM 's3://duckdb-series2-2026/large/admission/*/*.parquet'
WHERE year = 2021
GROUP BY ALL
ORDER BY admissions DESC, facility_code
LIMIT 5;

SELECT count(*) AS requests,
       format_bytes(sum(TRY_CAST(response.headers['Content-Length'] AS BIGINT))::BIGINT) AS bytes
FROM duckdb_logs_parsed('HTTP');
CALL truncate_duckdb_logs();

-- 3b. Every column of every year: the whole dataset comes over the network.
-- Skip it on a phone hotspot; the dry-run figure is on the backup slide.
SELECT count(COLUMNS(*)) FROM 's3://duckdb-series2-2026/large/admission/*/*.parquet';

SELECT count(*) AS requests,
       format_bytes(sum(TRY_CAST(response.headers['Content-Length'] AS BIGINT))::BIGINT) AS bytes
FROM duckdb_logs_parsed('HTTP');
CALL truncate_duckdb_logs();

-- The plan shows the pruning: "File Filters" on year and "Scanning Files: 4/16".
EXPLAIN ANALYZE
SELECT facility_code, count(*) AS admissions
FROM 's3://duckdb-series2-2026/large/admission/*/*.parquet'
WHERE year = 2021
GROUP BY ALL;

-- 4. The brief question: which hospitals carry the load, 2021 vs 2020? The
-- admissions stay on S3; facility_clean is the local table from Challenge 5.
-- Bed-days are counted as C4's los_days is: discharge date minus admit date.
-- No facility_clean in this Work database? Load C5's Checkpoint first.
CREATE TABLE IF NOT EXISTS facility_clean AS FROM 'expected/facility_clean.parquet';

CREATE OR REPLACE TABLE hospital_load_national AS
WITH load AS (
  SELECT facility_code,
         count(*) FILTER (WHERE year = 2020) AS admissions_2020,
         count(*) FILTER (WHERE year = 2021) AS admissions_2021,
         sum(date_diff('day', admit_ts::DATE, discharge_ts::DATE)) FILTER (WHERE year = 2020)::BIGINT AS bed_days_2020,
         sum(date_diff('day', admit_ts::DATE, discharge_ts::DATE)) FILTER (WHERE year = 2021)::BIGINT AS bed_days_2021
  FROM 's3://duckdb-series2-2026/large/admission/*/*.parquet'
  WHERE year IN (2020, 2021)
  GROUP BY ALL
)
SELECT f.state, f.facility_name, l.*,
       round(100 * (admissions_2021 - admissions_2020) / admissions_2020, 1) AS admissions_change_pct
FROM load l
JOIN facility_clean f USING (facility_code)
ORDER BY admissions_2021 DESC, facility_code
LIMIT 10;

FROM hospital_load_national;

-- 5. Bring home the answer, not the data: ten rows, written next to the bundle.
COPY hospital_load_national TO 'hospital_load_national.parquet';
