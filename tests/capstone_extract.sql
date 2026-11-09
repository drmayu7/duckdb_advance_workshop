-- The 2021 Capstone extract (#7, #10, #31), on the committed data/capstone/
-- files (tests/generator_determinism.sh proves they are current): one Parquet
-- file per month from the new system, Sabah's hospitals still on the old HIS
-- as one CSV per month, and a manifest whose row counts a careful read gives.
CREATE TABLE manifest AS FROM read_csv('data/capstone/manifest.csv', header = true, all_varchar = true);

CREATE TABLE sabah AS
FROM read_csv('data/capstone/2021-*-sabah.csv', header = true, all_varchar = true, filename = true);
CREATE TABLE new_his AS FROM read_parquet('data/capstone/2021-*.parquet', filename = true);

CREATE TABLE file_rows AS
SELECT parse_filename(filename) AS file, count(*) AS n FROM sabah GROUP BY ALL
UNION ALL
SELECT parse_filename(filename), count(*) FROM new_his GROUP BY ALL;

SELECT assert_eq('manifest has the file and rows columns', (SELECT string_agg(column_name, ',') FROM (DESCRIBE manifest)), 'file,rows');

SELECT assert_eq('one Parquet and one Sabah CSV per month of 2021',
                 (SELECT string_agg(file, ',' ORDER BY file) FROM file_rows),
                 (SELECT string_agg(f, ',' ORDER BY f) FROM (
                    SELECT strftime(m, '%Y-%m') || s AS f
                    FROM range(DATE '2021-01-01', DATE '2022-01-01', INTERVAL 1 MONTH) t(m), (VALUES ('.parquet'), ('-sabah.csv')) v(s))));

SELECT assert_eq('manifest lists exactly the files on disk', count(*), 0)
FROM (SELECT file FROM manifest EXCEPT SELECT file FROM file_rows
      UNION ALL SELECT file FROM file_rows EXCEPT SELECT file FROM manifest);

SELECT assert_eq('each file has the rows the manifest says', count(*), 0)
FROM manifest JOIN file_rows USING (file) WHERE manifest.rows::BIGINT <> file_rows.n;

SELECT assert_eq('about 25k admissions in 2021', sum(n) BETWEEN 22000 AND 32000, true) FROM file_rows;

-- One record per 2021 admission of the clean truth: no copies, none missing.
SELECT assert_eq('the extract holds every 2021 admission of the truth, once',
  (SELECT sum(n) FROM file_rows),
  (SELECT count(*) FROM 'generator/truth/admission.parquet' WHERE year(admit_ts) = 2021));

-- Sabah's hospitals are on the old HIS; every other hospital is on the new system.
CREATE TABLE hospital AS
SELECT KOD_FASILITI AS facility_code, NEGERI AS state
FROM read_json('data/open/facilities.json') WHERE KATEGORI_FASILITI = 'HOSPITAL';

SELECT assert_eq('the Sabah CSVs hold Sabah hospitals only, and all of them with admissions',
  (SELECT string_agg(DISTINCT h.state, ',') FROM sabah s JOIN hospital h ON h.facility_code = s.kod_fasiliti)
  || ' ' || (SELECT count(DISTINCT kod_fasiliti) FROM sabah)
  || ' ' || (SELECT count(*) FROM new_his n JOIN hospital h USING (facility_code) WHERE h.state = 'SABAH'),
  'SABAH ' || (SELECT count(DISTINCT a.facility_code) FROM 'generator/truth/admission.parquet' a JOIN hospital h USING (facility_code)
               WHERE h.state = 'SABAH' AND year(a.admit_ts) = 2021) || ' 0');

SELECT assert_eq('Sabah CSV has the old HIS Malay columns',
  (SELECT string_agg(name, ',') FROM (SELECT unnest(Columns).name AS name FROM sniff_csv('data/capstone/2021-06-sabah.csv', all_varchar = true))),
  'no_mrn,no_kp,nama,tarikh_lahir,jantina,negeri,daerah,poskod,alamat,kod_fasiliti,tarikh_masuk,tarikh_keluar,status_discaj,dx_utama,dx_sekunder,dikemaskini');

SELECT assert_eq('2021 Parquet has the new system columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE FROM 'data/capstone/2021-06.parquet')),
  'mrn VARCHAR,mykad VARCHAR,name VARCHAR,dob DATE,sex VARCHAR,state VARCHAR,district VARCHAR,postcode VARCHAR,address VARCHAR,facility_code VARCHAR,admit_ts TIMESTAMP,discharge_ts TIMESTAMP,discharge_status VARCHAR,principal_dx VARCHAR,secondary_dx VARCHAR,updated_at VARCHAR,ward VARCHAR,admission_type VARCHAR');

-- A plain read works: the Held-back defects give wrong numbers, not errors (#10).
SELECT assert_eq('a plain read_csv of every Sabah CSV gives the manifest''s rows',
  (SELECT count(*) FROM read_csv('data/capstone/2021-*-sabah.csv')),
  (SELECT sum(rows::BIGINT) FROM manifest WHERE file LIKE '%-sabah.csv'));

-- capstone_truth/ holds one truth table per Angle (#10), for the facilitator's diff.
SELECT assert_eq('Angle A truth: diabetes readmission by state, all 16 states',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE FROM 'capstone_truth/readmit_2021.parquet'))
  || ' ' || (SELECT count(*) FROM 'capstone_truth/readmit_2021.parquet'),
  'state VARCHAR,index_episodes BIGINT,readmissions BIGINT,readmit_pct DOUBLE 16');

SELECT assert_eq('Angle B truth: dengue admissions per 100k by state, all 16 states',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE FROM 'capstone_truth/dengue_2021.parquet'))
  || ' ' || (SELECT count(*) FROM 'capstone_truth/dengue_2021.parquet'),
  'state VARCHAR,dengue_admissions BIGINT,adm_per_100k DOUBLE 16');

SELECT assert_eq('Angle C truth: load per hospital, all 166 hospitals',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE FROM 'capstone_truth/hospital_load_2021.parquet'))
  || ' ' || (SELECT count(*) FROM 'capstone_truth/hospital_load_2021.parquet'),
  'state VARCHAR,facility_code VARCHAR,facility_name VARCHAR,admissions BIGINT,bed_days BIGINT,state_share_pct DOUBLE,state_rank BIGINT 166');

-- Independent spot checks of the truth against the clean truth tables.
SELECT assert_eq('Angle B truth counts every 2021 A97.x admission once',
  (SELECT sum(dengue_admissions) FROM 'capstone_truth/dengue_2021.parquet'),
  (SELECT count(*) FROM 'generator/truth/admission.parquet' WHERE year(admit_ts) = 2021 AND principal_dx LIKE 'A97.%'));

SELECT assert_eq('Angle C truth counts every 2021 admission once',
  (SELECT sum(admissions) FROM 'capstone_truth/hospital_load_2021.parquet'),
  (SELECT count(*) FROM 'generator/truth/admission.parquet' WHERE year(admit_ts) = 2021));

SELECT assert_eq('Angle A truth: every state has diabetes index episodes, and readmissions are a share of them', count(*), 0)
FROM 'capstone_truth/readmit_2021.parquet' WHERE index_episodes = 0 OR readmissions > index_episodes;
