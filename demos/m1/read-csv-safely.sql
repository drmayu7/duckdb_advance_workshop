-- Demo: reading a CSV you don't trust (Module 1, before C1, facilitator only, ~10 min).
-- A made-up five-line bed feed; the hospital names are real.
--
-- Run in the DuckDB UI from the bundle folder. The setup cell writes
-- beds_feed.csv next to your Work database, the way a hospital would send it.

-- begin setup
COPY (FROM (VALUES ('hospital,state,beds'),
                   ('Hospital Kuala Lipis,Pahang,120'),
                   ('Hospital Raub,Pahang,tiada'),
                   ('"Hospital Jerantut, Pahang",Pahang,95'),
                   ('Hospital Bentong,Pahang'),
                   ('Hospital Temerloh,Pahang,410')))
TO 'beds_feed.csv' (HEADER false, QUOTE '', ESCAPE '', DELIMITER '|');
-- end setup

-- 1. A plain read gives one column, not three. The sniffer looks for one
-- delimiter that fits every line; line 5 is a field short, so nothing fits.
FROM 'beds_feed.csv';

-- 2. Ask the sniffer what it decided, before trusting any count.
SELECT Delimiter, Quote, HasHeader, len(Columns) AS columns
FROM sniff_csv('beds_feed.csv');

-- 3. Say what you expect, and keep what doesn't fit. Bad lines go to the
-- reject_errors table instead of stopping the read, or vanishing.
SELECT * FROM read_csv('beds_feed.csv', delim = ',', types = {'beds': 'INTEGER'},
                       store_rejects = true);

SELECT line, column_name, error_type, csv_line FROM reject_errors;

-- 4. Keep every line: read everything as text, pad short lines with NULL and
-- record the file name. Then count, and compare with what the sender says.
SELECT * EXCLUDE (filename), parse_filename(filename) AS file
FROM read_csv('beds_feed.csv', delim = ',', all_varchar = true,
              null_padding = true, filename = true);

SELECT count(*) AS rows_read, 5 AS rows_sent
FROM read_csv('beds_feed.csv', delim = ',', all_varchar = true, null_padding = true);
