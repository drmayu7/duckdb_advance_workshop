-- Demo: CSV vs Parquet at 30 million rows (Module 1, facilitator only).
-- Synthetic data, not real hospital performance.
--
-- Run in the DuckDB UI from the bundle folder, with the large dataset unzipped
-- there (large/, from duckdb-large-2018-2021.zip or `./build.sh large`). The
-- same 30M admissions, once as one CSV and once as 16 Parquet files: run each
-- pair of cells and compare the run time the UI shows under the cell.

-- Before the session (about 20 s, writes 3.3 GiB): the same admissions as
-- one CSV, the way a hospital system usually exports them.
COPY (SELECT * EXCLUDE (year) FROM 'large/admission/*/*.parquet') TO 'admission_2018_2021.csv';

-- 1. Size on disk. Parquet stores each column together and compresses it.
SELECT 'CSV' AS format, count(*) AS files, format_bytes(sum(size)::BIGINT) AS on_disk
FROM read_blob('admission_2018_2021.csv')
UNION ALL
SELECT 'Parquet', count(*), format_bytes(sum(size)::BIGINT)
FROM read_blob('large/admission/*/*.parquet');

-- 2. How many rows? The CSV must be read line by line, end to end; Parquet
-- keeps the row count in each file's footer, so this reads almost nothing.
SELECT count(*) AS admissions FROM 'admission_2018_2021.csv';
SELECT count(*) AS admissions FROM 'large/admission/*/*.parquet';

-- 3. Types. A CSV holds only text, so DuckDB sniffs a type for each column:
-- secondary_dx comes back as text, not a list. Parquet stores the types
-- (TIMESTAMP, VARCHAR[]), and year comes from the folder names.
DESCRIBE FROM 'admission_2018_2021.csv';
DESCRIBE FROM 'large/admission/*/*.parquet';

-- 4. A real question: which hospitals were busiest in 2021? The CSV query
-- parses every column of every row. The Parquet query reads two columns, and
-- skips every row group whose stored admit_ts range is outside 2021.
SELECT facility_code, count(*) AS admissions
FROM 'admission_2018_2021.csv'
WHERE admit_ts >= TIMESTAMP '2021-01-01'
GROUP BY ALL
ORDER BY admissions DESC, facility_code
LIMIT 5;

SELECT facility_code, count(*) AS admissions
FROM 'large/admission/*/*.parquet'
WHERE admit_ts >= TIMESTAMP '2021-01-01'
GROUP BY ALL
ORDER BY admissions DESC, facility_code
LIMIT 5;

-- 5. With Hive partitioning the filter is on the folder name: only the
-- year=2021 files are opened. EXPLAIN ANALYZE shows "Scanning Files: 4/16".
EXPLAIN ANALYZE
SELECT facility_code, count(*) AS admissions
FROM 'large/admission/*/*.parquet'
WHERE year = 2021
GROUP BY ALL;
