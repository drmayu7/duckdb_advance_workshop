-- Demo: a table to a Google Sheet (Module 3, after pivot-export.sql,
-- facilitator only, 2 min). The Capstone's optional Stretch does the same
-- with a team's summary, into the team's MyGovUC Drive folder.
--
-- Before the session: make an empty Google Sheet in your MyGovUC Drive and
-- paste its URL over every <sheet URL> below. Then run the setup cell in the
-- DuckDB UI: the browser opens, sign in with the MyGovUC account, and paste
-- the token back into the cell if asked.

-- begin setup
LOAD gsheets;
CREATE SECRET (TYPE gsheet);
-- end setup

-- 1. COPY to the Sheet's URL, as to a file. The sheet is overwritten.
COPY population_by_year TO '<sheet URL>' (FORMAT gsheet);

-- 2. Read it back: the Sheet is a table to DuckDB too.
FROM read_gsheet('<sheet URL>');
