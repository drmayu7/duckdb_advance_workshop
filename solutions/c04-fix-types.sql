-- Reveal: C4, "Fix dates and numbers" (cards/c04-fix-types.md).
-- Run from the bundle folder, in your Work database, after C3 (or its Checkpoint).

-- Look first: every system writes dates its own way, and some cells mix formats
-- (DT01), hold Excel day numbers (DT03) or two-digit years (DT04).
SELECT source_system, dob, count(*) AS n
FROM admission_raw
WHERE NOT regexp_full_match(dob, '\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2}')
GROUP BY ALL
ORDER BY n DESC
LIMIT 20;

-- try_strptime gives NULL instead of an error, and takes a list of formats to try in turn.
SELECT try_strptime('03.04.2018', ['%d/%m/%Y', '%Y-%m-%d', '%d.%m.%Y']) AS parsed;

-- Careful: %Y reads any number of digits, so a two-digit year becomes year 18 AD.
SELECT strptime('03/04/18', '%d/%m/%Y') AS too_early;

-- Core: one typed table.
--   1. A null spelling (NU02, found in C2) becomes NULL, in every column at once.
--   2. Dates: try the five formats; a whole number left over is an Excel serial
--      day number (day 0 = 1899-12-30).
--   3. A placeholder date (DT05) or a year before 1900 (a two-digit year read
--      wrongly) becomes NULL.
--   4. Impossible stays (DT06) are kept, and flagged.
CREATE OR REPLACE TABLE admission_typed AS
WITH no_null_words AS (
  SELECT CASE WHEN upper(trim(COLUMNS(*))) IN ('NULL', 'N/A', 'NA', '-', 'TIADA', 'TIDAK DIKETAHUI', 'UNKNOWN')
              THEN NULL ELSE COLUMNS(*) END
  FROM admission_raw
),
parsed AS (
  SELECT * REPLACE (
           coalesce(try_strptime(dob, ['%d/%m/%Y', '%Y-%m-%d', '%d.%m.%Y', '%Y%m%d', '%d-%b-%Y'])::DATE,
                    DATE '1899-12-30' + TRY_CAST(dob AS INTEGER)) AS dob,
           coalesce(try_strptime(admit_date, ['%d/%m/%Y', '%Y-%m-%d', '%d.%m.%Y', '%Y%m%d', '%d-%b-%Y'])::DATE,
                    DATE '1899-12-30' + TRY_CAST(admit_date AS INTEGER)) AS admit_date,
           coalesce(try_strptime(discharge_date, ['%d/%m/%Y', '%Y-%m-%d', '%d.%m.%Y', '%Y%m%d', '%d-%b-%Y'])::DATE,
                    DATE '1899-12-30' + TRY_CAST(discharge_date AS INTEGER)) AS discharge_date,
           try_strptime(updated_at, ['%d/%m/%Y %H:%M', '%Y-%m-%d %H:%M:%S']) AS updated_at)
  FROM no_null_words
),
no_placeholders AS (
  -- COLUMNS([...]) applies one expression to the three date columns, keeping their names.
  SELECT * EXCLUDE (dob, admit_date, discharge_date),
         CASE WHEN COLUMNS(['dob', 'admit_date', 'discharge_date']) IN (DATE '1900-01-01', DATE '1970-01-01', DATE '9999-12-31')
                OR year(COLUMNS(['dob', 'admit_date', 'discharge_date'])) < 1900
              THEN NULL ELSE COLUMNS(['dob', 'admit_date', 'discharge_date']) END
  FROM parsed
)
SELECT source_system, mrn, mykad, name, dob, sex, state, district, postcode, address, facility_code,
       admit_date, discharge_date,
       date_diff('day', admit_date, discharge_date) AS los_days,
       CASE WHEN discharge_date < admit_date THEN 'discharge_before_admit'
            WHEN date_diff('day', admit_date, discharge_date) >= 365 THEN 'stay_365_days_or_more' END AS date_flag,
       discharge_status, principal_dx, secondary_dx, updated_at, ward, admission_type, file
FROM no_placeholders;

-- Proof that every admission and update date was read (want 0 and 0).
SELECT count(*) FILTER (WHERE admit_date IS NULL) AS admit_unread,
       count(*) FILTER (WHERE updated_at IS NULL) AS updated_unread
FROM admission_typed;

-- The flagged stays.
SELECT date_flag, count(*) AS stays FROM admission_typed WHERE date_flag IS NOT NULL GROUP BY ALL ORDER BY ALL;

-- Stretch S1: two-digit years (DT04), all in old HIS birth dates. The file
-- name gives the admit year: a two-digit year after its last two digits is
-- 19YY, otherwise 20YY.
SELECT dob AS written, file,
       make_date(CASE WHEN dob[-2:]::INTEGER > file[3:4]::INTEGER THEN 1900 ELSE 2000 END + dob[-2:]::INTEGER,
                 dob[4:5]::INTEGER, dob[1:2]::INTEGER) AS dob
FROM admission_raw
WHERE regexp_full_match(dob, '\d{2}/\d{2}/\d{2}')
ORDER BY file, written
LIMIT 10;

-- Stretch S2: which date formats each system really used, by the shape of the text.
SELECT source_system,
       regexp_replace(regexp_replace(admit_date, '[0-9]', '9', 'g'), '[A-Za-z]', 'a', 'g') AS shape,
       count(*) AS n
FROM admission_raw
GROUP BY ALL
ORDER BY source_system, n DESC;
