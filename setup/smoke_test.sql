-- The setup check. start-workshop runs it after install.sql, from the bundle
-- folder, against an in-memory database, with no internet. It prints one line:
--   SETUP OK (n/n) · Content <id>
--   SETUP FAILED (k/n): <code> <reason>; <code> <reason> · Content <id>
-- where k checks of n passed, and every failing code is listed. <id> comes from
-- release.txt, which each Content release lays over the bundle; before any, it is
-- `none` and the content check C1 is left out. The Fix sheet on
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

-- U1: the launcher sets WORKSHOP_U1=1 when a zip in updates/ could not be applied.
INSERT INTO passed SELECT 'U1' WHERE coalesce(getenv('WORKSHOP_U1'), '') <> '1';

-- The Content release, if one has been applied. glob finds nothing before the
-- first one, and reading an empty file list gives no rows, so a Setup-only bundle
-- shows `Content none`, leaves C1 out, and logs no errors.
SET VARIABLE release_files = (SELECT coalesce(list(file), []) FROM glob('release.txt'));
SET VARIABLE manifest_files = (SELECT coalesce(list(file), []) FROM glob('content_manifest.csv'));
SET VARIABLE content_id = (
  SELECT coalesce(nullif(regexp_extract(content, '[0-9]{8}-[0-9]{4}'), ''), 'unknown')
  FROM read_text(getvariable('release_files')));

-- C1: every file in content_manifest.csv (path,size; paths hold no commas) is
-- here, with the size it shipped with. read_blob fails on a missing file, so the
-- check does too, as it does when the manifest itself is missing. Paths are
-- compared with / separators.
CREATE TEMP TABLE shipped AS
SELECT split_part(line, ',', 1) AS path, TRY_CAST(split_part(line, ',', 2) AS BIGINT) AS size
FROM (SELECT unnest(string_split(replace(content, chr(13), ''), chr(10))) AS line
      FROM read_text(getvariable('manifest_files')))
WHERE line <> '' AND line <> 'path,size';
SET VARIABLE content_files = (SELECT coalesce(list(path), []) FROM shipped);
INSERT INTO passed
SELECT 'C1'
FROM shipped
LEFT JOIN (SELECT regexp_replace(replace(filename, '\', '/'), '^\./', '') AS path, size
           FROM read_blob(getvariable('content_files'))) AS found
  ON found.path = shipped.path AND found.size = shipped.size
HAVING count(*) > 0 AND count(*) = count(found.path);

-- The banner.
SELECT CASE WHEN count(*) FILTER (WHERE NOT ok) = 0
            THEN 'SETUP OK (' || count(*) || '/' || count(*) || ')'
            ELSE 'SETUP FAILED (' || count(*) FILTER (WHERE ok) || '/' || count(*) || '): '
                 || string_agg(code || ' ' || reason, '; ' ORDER BY ord) FILTER (WHERE NOT ok)
       END || ' · Content ' || coalesce(getvariable('content_id'), 'none') AS banner
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
    (14, 'F1',          'the bundle folder is under OneDrive, Desktop or Documents'),
    (15, 'U1',          'an update in the updates folder could not be applied')
  ) AS c(ord, code, reason)
  UNION ALL
  SELECT 16, 'C1', 'content incomplete (a file is missing or the wrong size)', 'C1' IN (SELECT code FROM passed)
  WHERE getvariable('content_id') IS NOT NULL
);
