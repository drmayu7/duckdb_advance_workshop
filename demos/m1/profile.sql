-- Demo: profiling before you trust (Module 1, before C2, facilitator only, ~10 min).
-- Real open data: MoH hospital bed counts and utilisation.
--
-- Run in the DuckDB UI from the bundle folder.

-- 1. SUMMARIZE profiles every column at once: type, min, max, distinct values,
-- null percentage. Read min and max first: they show odd values fastest.
-- Here: a hospital with -4 beds, and a utilisation of -1525 %.
SUMMARIZE FROM 'data/open/bed_utilisation.csv';

-- 2. COLUMNS(*) repeats one expression over every column: here, how many NULLs
-- each column holds, in one row.
SELECT count(*) FILTER (WHERE COLUMNS(*) IS NULL)
FROM 'data/open/bed_utilisation.csv';

-- 3. Zero is not missing. Hospitals with no ICU have 0 ICU beds, so their ICU
-- utilisation is NULL: those NULLs have a reason. The 40 rows with no beds
-- figure at all are a different story. Check before you "fix" either.
SELECT beds_icu = 0 AS no_icu_beds,
       count(*) AS hospitals,
       count(*) FILTER (WHERE util_icu IS NULL) AS util_icu_null
FROM 'data/open/bed_utilisation.csv'
GROUP BY ALL
ORDER BY ALL;

-- 4. COLUMNS() also takes a pattern: the average of every utilisation column.
SELECT round(avg(COLUMNS('^util_')), 1)
FROM 'data/open/bed_utilisation.csv';
