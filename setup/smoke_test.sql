-- The setup check. start-workshop runs it after install.sql, from the bundle
-- folder, against an in-memory database, with no internet. It prints one line:
--   SETUP OK (n/n) · Content none
--   SETUP FAILED (k/n): <code> <reason>; <code> <reason> · Content none
-- where k checks of n passed, and every failing code is listed. The Fix sheet on
-- the setup card says what to do for each code. This line, not the exit code, is
-- the result.
--
-- Each check that passes adds its code to `passed`. A check that errors adds
-- nothing, so it shows as failed. Autoinstall is off, so a missing extension fails
-- here instead of quietly downloading itself.
.bail off
.mode list
.headers off
SET autoinstall_known_extensions = false;
SET autoload_known_extensions = false;
CREATE TEMP TABLE passed (code VARCHAR);

-- V1: this is the bundle's DuckDB, not another one installed on the laptop.
INSERT INTO passed SELECT 'V1' WHERE version() = 'v1.5.6';

-- E-<ext>: each extension loads from the per-user folder.
LOAD ui;
LOAD httpfs;
LOAD aws;
LOAD spatial;
LOAD excel;
LOAD stats_duck;
LOAD rapidfuzz;
LOAD splink_udfs;
LOAD gsheets;
INSERT INTO passed SELECT 'E-' || extension_name FROM duckdb_extensions() WHERE loaded;

-- D1: every file listed in data/open/SHA256SUMS (the release's list of its open
-- data) is here. A missing SHA256SUMS fails the check too.
INSERT INTO passed
SELECT 'D1'
FROM (SELECT split_part(line, '  ', 2) AS name
      FROM read_csv('data/open/SHA256SUMS', header = false, delim = '\t', columns = {'line': 'VARCHAR'})) AS shipped
LEFT JOIN (SELECT regexp_extract(file, '[^/\\]+$') AS name FROM glob('data/open/*')) AS found USING (name)
HAVING count(*) > 0 AND count(*) = count(found.name);

-- W1: a new file can be written into the bundle folder, and read back.
SET VARIABLE w1_token = uuid()::VARCHAR;
COPY (SELECT getvariable('w1_token') AS token) TO '.setup_check.csv' (FORMAT csv, HEADER true);
INSERT INTO passed
SELECT 'W1' FROM read_csv('.setup_check.csv', header = true, columns = {'token': 'VARCHAR'})
WHERE token = getvariable('w1_token');

-- W2: the Work database opens. It fails when another DuckDB window holds it.
ATTACH 'my_work.duckdb' AS my_work;
INSERT INTO passed SELECT 'W2' FROM duckdb_databases() WHERE database_name = 'my_work';
DETACH my_work;

-- F1: the launcher sets WORKSHOP_F1=1 when the folder is under OneDrive (Windows)
-- or Desktop/Documents (Mac), where syncing can corrupt my_work.duckdb.
INSERT INTO passed SELECT 'F1' WHERE coalesce(getenv('WORKSHOP_F1'), '') <> '1';

-- The banner.
SELECT CASE WHEN count(*) FILTER (WHERE NOT ok) = 0
            THEN 'SETUP OK (' || count(*) || '/' || count(*) || ')'
            ELSE 'SETUP FAILED (' || count(*) FILTER (WHERE ok) || '/' || count(*) || '): '
                 || string_agg(code || ' ' || reason, '; ' ORDER BY ord) FILTER (WHERE NOT ok)
       END || ' · Content none' AS banner
FROM (
  SELECT c.ord, c.code, c.reason, c.code IN (SELECT code FROM passed) AS ok
  FROM (VALUES
    (1,  'V1',          'this is not DuckDB v1.5.6, start with start-workshop'),
    (2,  'E-ui',        'extension ui did not load'),
    (3,  'E-httpfs',    'extension httpfs did not load'),
    (4,  'E-aws',       'extension aws did not load'),
    (5,  'E-spatial',   'extension spatial did not load'),
    (6,  'E-excel',     'extension excel did not load'),
    (7,  'E-stats_duck', 'extension stats_duck did not load'),
    (8,  'E-rapidfuzz', 'extension rapidfuzz did not load'),
    (9,  'E-splink_udfs', 'extension splink_udfs did not load'),
    (10, 'E-gsheets',   'extension gsheets did not load'),
    (11, 'D1',          'data/open is missing or incomplete'),
    (12, 'W1',          'the bundle folder is not writable'),
    (13, 'W2',          'my_work.duckdb is open in another DuckDB window, or cannot be created'),
    (14, 'F1',          'the bundle folder is under OneDrive, Desktop or Documents')
  ) AS c(ord, code, reason)
);
