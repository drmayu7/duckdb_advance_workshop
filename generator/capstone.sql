-- The 2021 Capstone extract (#7, #10, #31), its Answer key rows, and
-- capstone_truth/. Runs after truth.sql and raw.sql in the same session, from
-- the output root, and reuses raw.sql's raw_columns, csv_field, fmt_ts and
-- fmt_updated. Then writes the whole Answer key (raw.sql's rows first).
--
-- Every 2021 admission becomes one raw record in its admit month's file. Sabah's
-- hospitals are still on the old HIS (CSV, Malay column names, DD/MM/YYYY);
-- every other hospital is on the new system (Parquet, typed dob/admit_ts/
-- discharge_ts, plus ward and admission_type), as in 2020.
--
-- The extract carries none of the taught defects: a team's C1-C10 SQL, adapted
-- to the 2021 files, cleans it as it is. It carries the three Held-back
-- defects only, one per Angle of the State Health Brief (#10), each giving a
-- wrong number rather than an error:
--   ID06 (Angle A, readmission): non-MyKad identifiers in the IC column;
--   DX04 (Angle B, dengue): free-text Malay/English diagnoses;
--   DT02 (Angle C, hospital load): one hospital exporting MM/DD dates.
-- The fixes, and how each defect also touches the other Angles:
-- capstone_truth/README.md.

-- ------------------------------------------------------------- raw records
CREATE TABLE cx AS
WITH a AS (
  SELECT a.*, p.mykad, p.name, p.dob, p.sex, p.state, p.district, p.postcode, p.address,
         h.state = 'SABAH' AS sabah,
         a.discharge_ts + to_minutes((60 + floor(u(a.admission_id, 'updated') * 2820))::BIGINT) AS updated_ts
  FROM admission a JOIN patient p USING (patient_id) JOIN ref_hospital h USING (facility_code)
  WHERE year(a.admit_ts) = 2021
)
SELECT admission_id AS rid, admission_id, patient_id,
       CASE WHEN sabah THEN 'old_his' ELSE 'new_his' END AS sys,
       strftime(admit_ts, '%Y-%m') || CASE WHEN sabah THEN '-sabah.csv' ELSE '.parquet' END AS file,
       mrn, mykad, name,
       CASE WHEN sabah THEN strftime(dob, '%d/%m/%Y') ELSE strftime(dob, '%Y-%m-%d') END AS dob,
       sex, state, district, postcode, address, facility_code,
       fmt_ts(CASE WHEN sabah THEN 'old_his' ELSE 'new_his' END, admit_ts) AS admit,
       fmt_ts(CASE WHEN sabah THEN 'old_his' ELSE 'new_his' END, discharge_ts) AS discharge,
       discharge_status, principal_dx,
       nullif(array_to_string(secondary_dx, '; '), '') AS secondary_dx,
       fmt_updated(CASE WHEN sabah THEN 'old_his' ELSE 'new_his' END, updated_ts) AS updated_at,
       CASE WHEN NOT sabah THEN ward END AS ward,
       CASE WHEN NOT sabah THEN admission_type END AS admission_type,
       admit_ts, discharge_ts, updated_ts
FROM a;

CREATE TABLE cdq (rid BIGINT, file VARCHAR, col VARCHAR, defect_code VARCHAR, dirty_value VARCHAR, clean_value VARCHAR);

-- ID06 (Angle A): patients without a MyKad. Foreign workers and visitors are
-- registered by passport or another document number, written in the IC column
-- on every admission. Most are in Sabah and the states with many foreign
-- workers. They are 2021's new patients (no admission before 2021), and each
-- keeps one identifier. Every form has fewer than 9 digits, so C6's
-- norm_mykad() gives NULL for all of them: they become one "patient". C6 keeps
-- one of its admissions per day, and C8 chains the rest into one year-long
-- episode, so their index episodes and readmissions vanish (Sabah's 2021
-- readmission rate falls, and its hospitals lose admissions). The clean value
-- is NULL (there is no MyKad); the identifier itself is still the patient's key.
CREATE TABLE id06 AS
WITH new_2021 AS (
  SELECT patient_id FROM admission GROUP BY ALL HAVING min(year(admit_ts)) = 2021
)
SELECT p.patient_id,
       CASE floor(u(p.patient_id, 'id06f') * 3)::INTEGER
         WHEN 0 THEN 'A' || ((p.patient_id * 7919) % 90000000 + 10000000)::VARCHAR  -- passport: letter + 8 digits
         WHEN 1 THEN 'B' || ((p.patient_id * 7919) % 9000000 + 1000000)::VARCHAR    -- passport: letter + 7 digits
         ELSE 'RF' || ((p.patient_id * 7919) % 900000 + 100000)::VARCHAR             -- police/army: RF + 6 digits
       END AS identifier
FROM patient p JOIN new_2021 USING (patient_id)
WHERE u(p.patient_id, 'id06') < CASE
        WHEN p.state = 'SABAH' THEN 0.35
        WHEN p.state IN ('JOHOR', 'SELANGOR', 'WILAYAH PERSEKUTUAN KUALA LUMPUR', 'WILAYAH PERSEKUTUAN LABUAN') THEN 0.10
        ELSE 0.03 END;
INSERT INTO cdq SELECT rid, file, 'mykad', 'ID06', i.identifier, NULL FROM cx JOIN id06 i USING (patient_id);
UPDATE cx SET mykad = i.identifier FROM id06 i WHERE cx.patient_id = i.patient_id;

-- DX04 (Angle B): free-text diagnoses. The new system lets a clinician type a
-- diagnosis instead of picking a code, and the old HIS always did; dengue is
-- the diagnosis typed most. A typed text never normalises to an ICD-10 code,
-- so the admission drops out of scenario_group = 'dengue'. Each text says
-- which code it is, so the fix recovers the true code.
CREATE TABLE dx04_text (icd10 VARCHAR, malay VARCHAR[], english VARCHAR[]);
INSERT INTO dx04_text VALUES
  ('A97.0', ['Demam denggi', 'DEMAM DENGGI', 'demam denggi'], ['Dengue fever', 'DENGUE FEVER', 'Dengue without warning signs']),
  ('A97.1', ['Denggi dengan tanda amaran', 'DENGGI DGN TANDA AMARAN'], ['Dengue with warning signs', 'DENGUE WITH WARNING SIGNS']),
  ('A97.2', ['Denggi teruk', 'Demam denggi berdarah'], ['Severe dengue', 'SEVERE DENGUE']),
  ('A97.9', ['Denggi', 'DENGGI'], ['Dengue', 'DENGUE', 'dengue']),
  ('J18.9', ['Radang paru-paru', 'RADANG PARU-PARU'], ['Pneumonia', 'PNEUMONIA']),
  ('A09.9', ['Cirit-birit', 'Gastroenteritis akut'], ['Gastroenteritis', 'Acute gastroenteritis', 'AGE']),
  ('N39.0', ['Jangkitan saluran kencing'], ['Urinary tract infection', 'UTI']);
CREATE TABLE hit AS
SELECT rid, file, 'principal_dx' AS col,
       pick(CASE WHEN sys = 'old_his' OR u(rid, 'dx04l') < 0.3 THEN t.malay ELSE t.english END, u(rid, 'dx04v')) AS dirty,
       cx.principal_dx AS clean
FROM cx JOIN dx04_text t ON t.icd10 = cx.principal_dx
WHERE u(rid, 'dx04') < CASE WHEN cx.principal_dx LIKE 'A97.%' THEN 0.35 ELSE 0.15 END;
INSERT INTO cdq SELECT rid, file, col, 'DX04', dirty, clean FROM hit;
UPDATE cx SET principal_dx = hit.dirty FROM hit WHERE cx.rid = hit.rid;
DROP TABLE hit;

-- DT02 (Angle C): Hospital Queen Elizabeth, Sabah's busiest, exports every
-- date month first (MM/DD/YYYY) while the rest of the old HIS writes DD/MM/YYYY.
-- A day after the 12th then reads as no date at all, and an earlier one as
-- the wrong month, so the hospital's stays and bed days go wrong. A date whose
-- day and month are equal reads the same either way, so it is not a defect.
CREATE TABLE hit AS
WITH q AS (
  SELECT cx.*, p.dob AS true_dob FROM cx JOIN patient p USING (patient_id)
  WHERE sys = 'old_his' AND facility_code = '11-12060025'
)
SELECT rid, file, 'dob' AS col, strftime(true_dob, '%m/%d/%Y') AS dirty, dob AS clean FROM q
UNION ALL SELECT rid, file, 'admit', strftime(admit_ts, '%m/%d/%Y'), admit FROM q
UNION ALL SELECT rid, file, 'discharge', strftime(discharge_ts, '%m/%d/%Y'), discharge FROM q
UNION ALL SELECT rid, file, 'updated_at', strftime(updated_ts, '%m/%d/%Y %H:%M'), updated_at FROM q;
DELETE FROM hit WHERE dirty = clean;
INSERT INTO cdq SELECT rid, file, col, 'DT02', dirty, clean FROM hit;
UPDATE cx SET dob = hit.dirty FROM hit WHERE cx.rid = hit.rid AND hit.col = 'dob';
UPDATE cx SET admit = hit.dirty FROM hit WHERE cx.rid = hit.rid AND hit.col = 'admit';
UPDATE cx SET discharge = hit.dirty FROM hit WHERE cx.rid = hit.rid AND hit.col = 'discharge';
UPDATE cx SET updated_at = hit.dirty FROM hit WHERE cx.rid = hit.rid AND hit.col = 'updated_at';
DROP TABLE hit;

-- ------------------------------------------------------------------ writing
CREATE TABLE cx_csv_lines AS
SELECT file, 0 AS rid,
       (SELECT string_agg(old_his, ',' ORDER BY pos) FROM raw_columns WHERE old_his IS NOT NULL) AS line
FROM (SELECT DISTINCT file FROM cx WHERE sys = 'old_his')
UNION ALL
SELECT file, rid,
       concat_ws(',', csv_field(mrn), csv_field(mykad), csv_field(name), csv_field(dob), csv_field(sex),
                 csv_field(state), csv_field(district), csv_field(postcode), csv_field(address),
                 csv_field(facility_code), csv_field(admit), csv_field(discharge), csv_field(discharge_status),
                 csv_field(principal_dx), csv_field(secondary_dx), csv_field(updated_at))
FROM cx WHERE sys = 'old_his';

CREATE VIEW cx_new_his_rows AS
SELECT file, rid, mrn, mykad, name, dob::DATE AS dob, sex, state, district, postcode, address, facility_code,
       admit::TIMESTAMP AS admit_ts, discharge::TIMESTAMP AS discharge_ts, discharge_status, principal_dx,
       secondary_dx, updated_at, ward, admission_type
FROM cx WHERE sys = 'new_his';

COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-01-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-01-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-02-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-02-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-03-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-03-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-04-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-04-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-05-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-05-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-06-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-06-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-07-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-07-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-08-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-08-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-09-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-09-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-10-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-10-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-11-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-11-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM cx_csv_lines WHERE file = '2021-12-sabah.csv' ORDER BY rid) TO 'data/capstone/2021-12-sabah.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');

COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-01.parquet' ORDER BY rid) TO 'data/capstone/2021-01.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-02.parquet' ORDER BY rid) TO 'data/capstone/2021-02.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-03.parquet' ORDER BY rid) TO 'data/capstone/2021-03.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-04.parquet' ORDER BY rid) TO 'data/capstone/2021-04.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-05.parquet' ORDER BY rid) TO 'data/capstone/2021-05.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-06.parquet' ORDER BY rid) TO 'data/capstone/2021-06.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-07.parquet' ORDER BY rid) TO 'data/capstone/2021-07.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-08.parquet' ORDER BY rid) TO 'data/capstone/2021-08.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-09.parquet' ORDER BY rid) TO 'data/capstone/2021-09.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-10.parquet' ORDER BY rid) TO 'data/capstone/2021-10.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-11.parquet' ORDER BY rid) TO 'data/capstone/2021-11.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM cx_new_his_rows WHERE file = '2021-12.parquet' ORDER BY rid) TO 'data/capstone/2021-12.parquet' (FORMAT parquet, COMPRESSION zstd);

-- manifest.csv: the rows a correct read of each file gives.
COPY (SELECT file, count(*) AS rows FROM cx GROUP BY file ORDER BY file)
  TO 'data/capstone/manifest.csv' (FORMAT csv, HEADER true);

-- The Answer key: the 2021 rows after raw.sql's, then the whole key is written.
CREATE TABLE cx_row AS SELECT rid, file, row_number() OVER (PARTITION BY file ORDER BY rid) AS row_no FROM cx;
INSERT INTO answer_key
SELECT (SELECT max(seq) FROM answer_key) + row_number() OVER (ORDER BY d.file, r.row_no, c.pos, d.defect_code),
       'data/capstone/' || d.file, r.row_no,
       CASE WHEN d.file LIKE '%.csv' THEN c.old_his ELSE c.new_his END,
       d.defect_code, d.dirty_value, d.clean_value, d.rid
FROM cdq d JOIN raw_columns c USING (col) JOIN cx_row r USING (rid);

COPY (SELECT * EXCLUDE (seq) FROM answer_key ORDER BY seq)
  TO 'generator/dq_answer_key.parquet' (FORMAT parquet, COMPRESSION zstd);

-- ------------------------------------------------------------ capstone_truth
-- The true 2021 figure for each Angle, from the clean truth, with the
-- definitions the cards state (#7, #10): what a pipeline that adapts C1-C10 to
-- the 2021 files and fixes all three Held-back defects writes. 2021 on its
-- own: episodes and readmissions use 2021 admissions only.
CREATE TABLE t21 AS
SELECT a.patient_id, a.facility_code, a.admit_ts::DATE AS admit_date, a.discharge_ts::DATE AS discharge_date,
       a.principal_dx, a.discharge_status, p.state
FROM admission a JOIN patient p USING (patient_id)
WHERE year(a.admit_ts) = 2021;
CREATE TABLE icd AS FROM read_csv('data/open/ref_icd10.csv', header = true, all_varchar = true);

-- Angle A: diabetes 30-day readmission by state (C8 episodes, C9 readmission).
CREATE TABLE t21_episode AS
WITH marked AS (
  SELECT *, coalesce(admit_date > lag(discharge_date) OVER w + 1, true) AS starts_episode
  FROM t21 WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date)
),
numbered AS (
  SELECT *, sum(starts_episode::INTEGER) OVER (PARTITION BY patient_id ORDER BY admit_date) AS episode_no FROM marked
)
SELECT patient_id, episode_no,
       first(state ORDER BY admit_date) AS state,
       min(admit_date) AS episode_start, max(discharge_date) AS episode_end,
       first(principal_dx ORDER BY admit_date) AS principal_dx,
       first(discharge_status ORDER BY admit_date DESC) AS discharge_status
FROM numbered GROUP BY patient_id, episode_no;

COPY (
  WITH followed AS (
    SELECT *, lead(episode_start) OVER (PARTITION BY patient_id ORDER BY episode_no) AS next_start FROM t21_episode
  ),
  idx AS (
    SELECT state, coalesce(date_diff('day', episode_end, next_start) BETWEEN 1 AND 30, false) AS readmitted
    FROM followed
    WHERE principal_dx IN (SELECT icd10 FROM icd WHERE scenario_group = 'diabetes') AND discharge_status <> 'DIED'
  )
  SELECT state, count(*) AS index_episodes, count(*) FILTER (WHERE readmitted) AS readmissions,
         round(100 * readmissions / index_episodes, 1) AS readmit_pct
  FROM idx GROUP BY state ORDER BY state
) TO 'capstone_truth/readmit_2021.parquet' (FORMAT parquet, COMPRESSION zstd);

-- Angle B: dengue admissions per 100k people by state of residence (C10's
-- rate, with DOSM's 2021 population).
COPY (
  WITH people AS (
    SELECT replace(upper(state), 'W.P. ', 'WILAYAH PERSEKUTUAN ') AS state, round(population * 1000) AS people
    FROM 'data/open/population_state.parquet'
    WHERE year(date) = 2021 AND sex = 'both' AND age = 'overall' AND ethnicity = 'overall'
  ),
  admitted AS (
    SELECT state, count(*) AS dengue_admissions FROM t21
    WHERE principal_dx IN (SELECT icd10 FROM icd WHERE scenario_group = 'dengue') GROUP BY ALL
  )
  SELECT p.state, coalesce(a.dengue_admissions, 0) AS dengue_admissions,
         round(100000 * coalesce(a.dengue_admissions, 0) / p.people, 1) AS adm_per_100k
  FROM people p LEFT JOIN admitted a USING (state)
  ORDER BY state
) TO 'capstone_truth/dengue_2021.parquet' (FORMAT parquet, COMPRESSION zstd);

-- Angle C: the load on each of the 166 hospitals (C7's hospital_load).
COPY (
  WITH per_hospital AS (
    SELECT h.state, h.facility_code, h.facility_name,
           count(t.facility_code) AS admissions,
           coalesce(sum(date_diff('day', t.admit_date, t.discharge_date)), 0)::BIGINT AS bed_days
    FROM ref_hospital h LEFT JOIN t21 t USING (facility_code)
    GROUP BY ALL
  )
  SELECT *,
         round(100 * admissions / sum(admissions) OVER (PARTITION BY state), 1) AS state_share_pct,
         rank() OVER (PARTITION BY state ORDER BY admissions DESC) AS state_rank
  FROM per_hospital
  ORDER BY state, facility_code
) TO 'capstone_truth/hospital_load_2021.parquet' (FORMAT parquet, COMPRESSION zstd);
