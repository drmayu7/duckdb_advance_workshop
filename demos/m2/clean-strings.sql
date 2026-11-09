-- Demo: cleaning text with regex and macros (Module 2, before C5, facilitator only, ~10 min).
-- Real open data: dengue cases by state and age group (MOH).
--
-- Run in the DuckDB UI from the bundle folder.

-- 1. Look first: the age groups are written three ways (0-4, " 5 - 9", >75),
-- so a GROUP BY or a join on them quietly misses rows.
SELECT DISTINCT "KUMPULAN UMUR" AS age_group, length("KUMPULAN UMUR") AS chars
FROM 'data/open/dengue_state_age_2018_2021.csv'
ORDER BY ALL;

-- 2. trim() removes spaces at the ends; regexp_replace() rewrites a pattern
-- anywhere: \s* is "any spaces", so " 5 - 9" becomes "5-9".
SELECT DISTINCT "KUMPULAN UMUR" AS raw,
       regexp_replace(trim("KUMPULAN UMUR"), '\s*-\s*', '-') AS cleaned
FROM 'data/open/dengue_state_age_2018_2021.csv'
ORDER BY ALL;

-- 3. A macro is a rule with a name. Write it once, use it on every table, and
-- next year's file gets the same rule.
CREATE OR REPLACE MACRO clean_age(s) AS
  CASE WHEN trim(s) = '>75' THEN '75+'
       ELSE regexp_replace(trim(s), '\s*-\s*', '-')
  END;

SELECT clean_age(' 5 - 9') AS a, clean_age('10-14') AS b, clean_age('>75') AS c;

-- 4. Use it: Johor's dengue cases in 2019 by clean age group. Text sorts
-- "10-14" before "5-9", so sort by the number the group starts with.
SELECT clean_age("KUMPULAN UMUR") AS age_group, JOHOR AS cases
FROM 'data/open/dengue_state_age_2018_2021.csv'
WHERE TAHUN = 2019
ORDER BY TRY_CAST(regexp_extract(age_group, '^\d+') AS INTEGER);
