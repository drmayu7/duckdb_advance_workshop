-- The 2018–2020 Raw extract (#7, #23), on the committed data/raw/ files
-- (tests/generator_determinism.sh proves they are current): one file per month
-- from three source systems, and a manifest whose row counts are what a
-- careful read of each file gives.
CREATE TABLE manifest AS FROM read_csv('data/raw/manifest.csv', header = true, all_varchar = true);

CREATE TABLE file_rows AS
SELECT parse_filename(filename) AS file, count(*) AS n
FROM read_csv('data/raw/2018-*.csv', header = true, all_varchar = true, strict_mode = false, filename = true)
GROUP BY ALL
UNION ALL
SELECT parse_filename(filename), count(*) FROM read_json('data/raw/2019-*.json', filename = true) GROUP BY ALL
UNION ALL
SELECT parse_filename(filename), count(*) FROM read_parquet('data/raw/2020-*.parquet', filename = true) GROUP BY ALL;

SELECT assert_eq('manifest has the file and rows columns', (SELECT string_agg(column_name, ',') FROM (DESCRIBE manifest)), 'file,rows');

SELECT assert_eq('one file per month: 12 CSV (2018), 12 JSON (2019), 12 Parquet (2020)',
                 (SELECT string_agg(file, ',' ORDER BY file) FROM file_rows),
                 (SELECT string_agg(f, ',' ORDER BY f) FROM (
                    SELECT strftime(m, '%Y-%m') || CASE year(m) WHEN 2018 THEN '.csv' WHEN 2019 THEN '.json' ELSE '.parquet' END AS f
                    FROM range(DATE '2018-01-01', DATE '2021-01-01', INTERVAL 1 MONTH) t(m))));

SELECT assert_eq('manifest lists exactly the files on disk', count(*), 0)
FROM (SELECT file FROM manifest EXCEPT SELECT file FROM file_rows
      UNION ALL SELECT file FROM file_rows EXCEPT SELECT file FROM manifest);

SELECT assert_eq('each file has the rows the manifest says', count(*), 0)
FROM manifest JOIN file_rows USING (file) WHERE manifest.rows::BIGINT <> file_rows.n;

SELECT assert_eq('about 75k admissions in 2018-2020', sum(n) BETWEEN 70000 AND 80000, true) FROM file_rows;

-- Column names per source system (#7).
SELECT assert_eq('2018 CSV has the old HIS Malay columns',
  (SELECT string_agg(name, ',') FROM (SELECT unnest(Columns).name AS name FROM sniff_csv('data/raw/2018-06.csv', strict_mode = false, all_varchar = true))),
  'no_mrn,no_kp,nama,tarikh_lahir,jantina,negeri,daerah,poskod,alamat,kod_fasiliti,tarikh_masuk,tarikh_keluar,status_discaj,dx_utama,dx_sekunder,dikemaskini');

SELECT assert_eq('2019 JSON has the interim system columns',
  (SELECT string_agg(column_name, ',') FROM (DESCRIBE FROM read_json('data/raw/2019-06.json'))),
  'mrn,mykad,name,dob,sex,state,district,postcode,address,facility_code,admit_date,discharge_date,discharge_status,principal_dx,secondary_dx,updated_at');

SELECT assert_eq('2020 Parquet has the new system columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE FROM 'data/raw/2020-06.parquet')),
  'mrn VARCHAR,mykad VARCHAR,name VARCHAR,dob DATE,sex VARCHAR,state VARCHAR,district VARCHAR,postcode VARCHAR,address VARCHAR,facility_code VARCHAR,admit_ts TIMESTAMP,discharge_ts TIMESTAMP,discharge_status VARCHAR,principal_dx VARCHAR,secondary_dx VARCHAR,updated_at VARCHAR,ward VARCHAR,admission_type VARCHAR');

-- The trap C1 teaches: a plain read of an old HIS file does not give the manifest's rows.
SELECT assert_eq('a plain read_csv of 2018-01.csv disagrees with the manifest',
  (SELECT count(*) FROM read_csv('data/raw/2018-01.csv')) = (SELECT rows::BIGINT FROM manifest WHERE file = '2018-01.csv'), false);
