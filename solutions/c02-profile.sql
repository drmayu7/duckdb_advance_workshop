-- Reveal: C2, "Profile before you trust" (cards/c02-profile.md).
-- Run from the bundle folder, in your Work database, after C1 (or its Checkpoint).

-- A first look: SUMMARIZE profiles every column in one line. On text columns,
-- min and max compare strings, which is what gives the problems away:
--   * tarikh_lahir min 01/01/1900 and tarikh_keluar max 31/12/9999 are placeholder dates (DT05);
--   * nama, negeri, daerah min start with a space, and their max is lower case (TX01);
--   * null_percentage shows only real NULLs, not the words that mean "nothing" (NU02).
SUMMARIZE raw_2018;

-- Core: one row per measure, one column per raw_2018 column, in raw_2018's order.
CREATE OR REPLACE TABLE profile_nulls AS
SELECT 'is_null' AS measure,
       count(*) FILTER (WHERE COLUMNS(*) IS NULL)
FROM raw_2018
UNION ALL
SELECT 'null_spelling',
       count(*) FILTER (WHERE upper(trim(COLUMNS(*))) IN ('NULL', 'N/A', 'NA', '-', 'TIADA', 'TIDAK DIKETAHUI', 'UNKNOWN'))
FROM raw_2018
UNION ALL
SELECT 'padded',
       count(*) FILTER (WHERE COLUMNS(*) <> trim(COLUMNS(*), ' ' || chr(160)))
FROM raw_2018;

FROM profile_nulls;

-- Stretch S1: which null spellings, in which columns, and how often.
SELECT 'dx_sekunder' AS column_name, dx_sekunder AS value, count(*) AS n
FROM raw_2018
WHERE upper(trim(dx_sekunder)) IN ('NULL', 'N/A', 'NA', '-', 'TIADA', 'TIDAK DIKETAHUI', 'UNKNOWN')
GROUP BY ALL
UNION ALL
SELECT 'daerah', daerah, count(*)
FROM raw_2018
WHERE upper(trim(daerah)) IN ('NULL', 'N/A', 'NA', '-', 'TIADA', 'TIDAK DIKETAHUI', 'UNKNOWN')
GROUP BY ALL
UNION ALL
SELECT 'alamat', alamat, count(*)
FROM raw_2018
WHERE upper(trim(alamat)) IN ('NULL', 'N/A', 'NA', '-', 'TIADA', 'TIDAK DIKETAHUI', 'UNKNOWN')
GROUP BY ALL
ORDER BY column_name, n DESC, value;

-- Stretch S2: the placeholder dates, per column.
SELECT count(*) FILTER (WHERE tarikh_lahir IN ('01/01/1900', '01/01/1970')) AS placeholder_dob,
       count(*) FILTER (WHERE tarikh_keluar = '31/12/9999') AS placeholder_discharge
FROM raw_2018;
