-- Reveal: C1, "Read the 2018 CSVs safely" (cards/c01-read-csv.md).
-- Run from the bundle folder, in your Work database.

-- The manifest: how many records the old HIS says each file holds.
CREATE OR REPLACE TABLE manifest AS
SELECT * FROM read_csv('data/raw/manifest.csv');

-- 1. A plain read of January disagrees with the manifest.
SELECT (SELECT count(*) FROM 'data/raw/2018-01.csv') AS rows_read,
       (SELECT rows FROM manifest WHERE file = '2018-01.csv') AS manifest_rows;

-- 2. Why: the sniffer gave up. It found no quote character and no delimiter it
--    could trust, so it read each line as one column: every line break inside an
--    address starts a new row.
SELECT Delimiter, Quote, HasHeader, len(Columns) AS columns FROM sniff_csv('data/raw/2018-01.csv');

-- 3. Keeping rejects: most of the file is rejected, and only a few rows are left.
SELECT count(*) AS rows_read FROM read_csv('data/raw/2018-01.csv', store_rejects = true);

-- The rejects tables are temporary, so keep a copy in the Work database.
CREATE OR REPLACE TABLE rejects_2018 AS
SELECT scan_id, line, error_type, csv_line FROM reject_errors;

SELECT error_type, count(*) AS lines FROM rejects_2018 GROUP BY error_type;

-- 4. The fix. Some addresses have quotes inside a quoted field that the old HIS
--    did not double ("NO 5, JALAN "MAWAR" 3"). strict_mode = false reads them,
--    and all_varchar = true keeps every value exactly as the file has it.
SELECT count(*) AS rows_read
FROM read_csv('data/raw/2018-01.csv', all_varchar = true, strict_mode = false);

-- Core: all twelve months, every column as text, plus the file each row came from.
CREATE OR REPLACE TABLE raw_2018 AS
SELECT * EXCLUDE (filename), parse_filename(filename) AS file
FROM read_csv('data/raw/2018-*.csv', all_varchar = true, strict_mode = false, filename = true);

-- Proof that nothing was dropped: every file's row count against the manifest (0 rows).
SELECT m.file, m.rows AS manifest_rows, count(r.file) AS rows_read
FROM manifest AS m
LEFT JOIN raw_2018 AS r ON r.file = m.file
WHERE m.file LIKE '2018-%'
GROUP BY m.file, m.rows
HAVING count(r.file) <> m.rows;

-- Stretch S1: rejects per file for a plain read of all twelve files. The rejects
-- tables keep every scan of this session, so count only the latest scan.
SELECT count(*) AS rows_read FROM read_csv('data/raw/2018-*.csv', store_rejects = true);

SELECT parse_filename(s.file_path) AS file, count(*) AS rejected_lines
FROM reject_errors AS e
JOIN reject_scans AS s ON s.scan_id = e.scan_id AND s.file_id = e.file_id
WHERE e.scan_id = (SELECT max(scan_id) FROM reject_scans)
GROUP BY ALL
ORDER BY file;

-- Stretch S2: leading zeros the old HIS had already lost (it once stored them as numbers).
SELECT count(*) FILTER (WHERE length(no_kp) <> 14) AS ic_not_14_chars,
       count(*) FILTER (WHERE length(poskod) <> 5) AS postcode_not_5_digits
FROM raw_2018;
