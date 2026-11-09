-- Demo: messy dates and numbers (Module 2, before C4, facilitator only, ~10 min).
-- Made-up values, typed in the cell, the way three systems might write them.
--
-- Run in the DuckDB UI from the bundle folder.

-- 1. CAST stops the whole query at the first value it can't read:
-- CAST('tiada' AS INTEGER) is an error, not a row. TRY_CAST gives NULL instead,
-- so the query finishes and you can count what failed.
SELECT raw, TRY_CAST(raw AS INTEGER) AS beds
FROM (VALUES ('120'), (' 95 '), ('tiada'), ('1,156')) AS t(raw);

-- 2. try_strptime does the same for dates, and takes a list of formats: it uses
-- the first that fits. 43558 and 31/02/2019 fit none, so they stay NULL.
SELECT raw,
       try_strptime(raw, ['%d/%m/%Y', '%Y-%m-%d', '%d-%b-%Y'])::DATE AS as_date
FROM (VALUES ('03/04/2019'), ('2019-04-03'), ('03-Apr-2019'),
             ('43558'), ('31/02/2019')) AS t(raw);

-- 3. A whole number no format reads is often an Excel day number: day 0 is
-- 1899-12-30. coalesce keeps the first answer that isn't NULL.
SELECT raw,
       coalesce(try_strptime(raw, ['%d/%m/%Y', '%Y-%m-%d'])::DATE,
                DATE '1899-12-30' + TRY_CAST(raw AS INTEGER)) AS as_date
FROM (VALUES ('03/04/2019'), ('43558'), ('not yet')) AS t(raw);

-- 4. * REPLACE swaps columns for their typed versions in place, keeping the
-- column order; * EXCLUDE drops columns. No need to list every column again.
SELECT * REPLACE (try_strptime(admitted, '%d/%m/%Y')::DATE AS admitted,
                  TRY_CAST(beds AS INTEGER) AS beds)
FROM (VALUES ('Hospital Raub', '03/04/2019', '120'),
             ('Hospital Bentong', '04/04/2019', 'tiada')) AS t(hospital, admitted, beds);
