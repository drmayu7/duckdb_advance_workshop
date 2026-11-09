-- Clean truth for the MyHDW-like dataset (ADR 0001, #7): `patient` and `admission`,
-- 2017–2021. Pure DuckDB 1.5.6 SQL, run by `build.sh data` from the output root
-- (which has data/open/ and generator/names.csv). Every random draw is a hash of
-- the row's key and a salt, so two runs give identical tables. The `patients`
-- variable sets the scale (default 58000); `build.sh large` sets it to ~16.6M,
-- and since every draw is per patient, a bigger run keeps the small run's patients.
--
-- Invariants (tested in tests/generator_invariants.sql):
--   * a patient never has two admissions on the same day, and stays never overlap;
--   * admission_id increases with admit_ts;
--   * every IC is YYMMDD-PB-9##G: its DOB is the patient's dob, PB is a JPN
--     place-of-birth state code, G is odd for males (ADR 0003);
--   * state/district are the patient's residence, in MoH health-district names.
.bail on
-- build.sh large turns this off: at 30M admissions, keeping insertion order
-- runs an 8 GB laptop out of memory. Nothing here depends on it.
SET preserve_insertion_order = coalesce(getvariable('preserve_insertion_order'), true);

-- u(...): a uniform draw in [0, 1) from the hash of a key and a salt.
CREATE MACRO u(k, salt) AS (hash(k, salt) % 1000000)::DOUBLE / 1000000;
CREATE MACRO uk(k1, k2, salt) AS (hash(k1, k2, salt) % 1000000)::DOUBLE / 1000000;
-- pick(list, x): the element at fraction x in [0, 1) of the list.
CREATE MACRO pick(lst, x) AS lst[1 + floor(x * len(lst))::INTEGER];
-- expo(x, mean): an exponential draw from a uniform.
CREATE MACRO expo(x, mean) AS -ln(1 - x) * mean;

-- ---------------------------------------------------------------- references
CREATE TABLE names AS
SELECT kind, list(token ORDER BY token) AS tokens
FROM read_csv('generator/names.csv', header = true, all_varchar = true)
GROUP BY kind;
CREATE MACRO tokens(k) AS (SELECT tokens FROM names WHERE kind = k);

-- The 166 MoH hospitals. Integer weights keep every weighted pick exact.
CREATE TABLE ref_hospital AS
SELECT KOD_FASILITI AS facility_code,
       trim(regexp_replace(NAMA, '\s+', ' ', 'g')) AS facility_name,
       NEGERI AS state,
       trim(DAERAH) AS district,
       CASE JENIS_FASILITI
         WHEN 'HOSPITAL NEGERI' THEN 12 WHEN 'HOSPITAL PENGAJAR' THEN 10
         WHEN 'HOSPITAL PAKAR MAJOR' THEN 8 WHEN 'HOSPITAL PAKAR MINOR' THEN 5
         WHEN 'HOSPITAL TANPA PAKAR' THEN 2 ELSE 1 END AS size_weight,
       JENIS_FASILITI IN ('HOSPITAL NEGERI', 'HOSPITAL PENGAJAR', 'HOSPITAL PAKAR MAJOR') AS is_referral
FROM read_json('data/open/facilities.json')
WHERE KATEGORI_FASILITI = 'HOSPITAL';

-- Residence states, weighted by DOSM 2017 population, named as the MoH list names them.
CREATE TABLE ref_state AS
WITH s AS (
  SELECT replace(upper(state), 'W.P. ', 'WILAYAH PERSEKUTUAN ') AS state,
         round(population * 1000)::BIGINT AS w
  FROM 'data/open/population_state.parquet'
  WHERE date = DATE '2017-01-01' AND sex = 'both' AND age = 'overall' AND ethnicity = 'overall'
)
SELECT state, (sum(w) OVER (ORDER BY state) - w) / sum(w) OVER () AS lo,
       (SELECT count(*) FROM ref_hospital h WHERE h.state = s.state) AS hospitals
FROM s;

-- JPN place-of-birth codes per state; the first is the original code.
CREATE TABLE ref_pb (state VARCHAR, codes VARCHAR[]);
INSERT INTO ref_pb VALUES
  ('JOHOR', ['01', '21', '22', '23', '24']), ('KEDAH', ['02', '25', '26', '27']),
  ('KELANTAN', ['03', '28', '29']), ('MELAKA', ['04', '30']),
  ('NEGERI SEMBILAN', ['05', '31', '59']), ('PAHANG', ['06', '32', '33']),
  ('PULAU PINANG', ['07', '34', '35']), ('PERAK', ['08', '36', '37', '38', '39']),
  ('PERLIS', ['09', '40']), ('SELANGOR', ['10', '41', '42', '43', '44']),
  ('TERENGGANU', ['11', '45', '46']), ('SABAH', ['12', '47', '48', '49']),
  ('SARAWAK', ['13', '50', '51', '52', '53']),
  ('WILAYAH PERSEKUTUAN KUALA LUMPUR', ['14', '54', '55', '56', '57']),
  ('WILAYAH PERSEKUTUAN LABUAN', ['15', '58']), ('WILAYAH PERSEKUTUAN PUTRAJAYA', ['16']);

-- Residence health districts: the facility list's DAERAH values with at least 3
-- facilities, weighted by facility count. Kuala Lumpur's facilities mostly carry
-- the merged pseudo-district, so its four real health districts are listed by hand.
CREATE TABLE ref_district AS
WITH f AS (
  SELECT CASE WHEN NEGERI = 'WILAYAH PERSEKUTUAN KUALA LUMPUR DAN PUTRAJAYA' AND trim(DAERAH) = 'PUTRAJAYA'
                THEN 'WILAYAH PERSEKUTUAN PUTRAJAYA'
              WHEN NEGERI LIKE 'WILAYAH PERSEKUTUAN KUALA LUMPUR%' THEN 'WILAYAH PERSEKUTUAN KUALA LUMPUR'
              ELSE NEGERI END AS state,
         trim(DAERAH) AS district,
         CASE WHEN regexp_full_match(POSKOD, '[0-9]{5}') THEN POSKOD END AS postcode
  FROM read_json('data/open/facilities.json')
),
d AS (
  SELECT state, district, count(*) AS w,
         list(DISTINCT postcode ORDER BY postcode) FILTER (postcode IS NOT NULL) AS postcodes
  FROM f
  WHERE state <> 'WILAYAH PERSEKUTUAN KUALA LUMPUR' AND district NOT LIKE 'WILAYAH PERSEKUTUAN%'
  GROUP BY ALL HAVING count(*) >= 3
  UNION ALL
  SELECT 'WILAYAH PERSEKUTUAN KUALA LUMPUR', kl.district, 1,
         (SELECT list(DISTINCT postcode ORDER BY postcode) FROM f
          WHERE state = 'WILAYAH PERSEKUTUAN KUALA LUMPUR' AND postcode IS NOT NULL)
  FROM (VALUES ('CHERAS'), ('KEPONG'), ('LEMBAH PANTAI'), ('TITIWANGSA')) kl(district)
)
SELECT state, district, postcodes,
       (sum(w) OVER (PARTITION BY state ORDER BY district) - w) / sum(w) OVER (PARTITION BY state) AS lo
FROM d;

-- Diagnosis codes per scenario group, repeated by weight so a uniform pick is weighted.
-- Legacy dengue A90/A91 never appear in the clean truth (DX02 injects them).
CREATE TABLE ref_dx AS
WITH w AS (
  SELECT scenario_group AS grp, icd10,
         CASE WHEN icd10 IN ('A90', 'A91') THEN 0
              WHEN icd10 LIKE 'E11.%' OR icd10 = 'A97.0' OR icd10 LIKE 'O80.%' THEN 6
              WHEN icd10 IN ('I10', 'I50.9', 'I63.9', 'I21.9', 'A97.1', 'J18.9', 'A09.9', 'N39.0', 'N18.5')
                   OR icd10 LIKE 'O82.%' THEN 3
              WHEN icd10 LIKE 'E14.%' OR icd10 IN ('A97.9', 'J44.1', 'J45.9', 'A41.9', 'O24.4', 'N17.9') THEN 2
              ELSE 1 END AS w
  FROM read_csv('data/open/ref_icd10.csv', header = true, all_varchar = true)
)
SELECT grp, flatten(list(list_resize([icd10], w, icd10) ORDER BY icd10)) AS codes
FROM w GROUP BY grp;

-- ------------------------------------------------------------------- patients
-- Each patient has a clinical profile that drives age, admission count and diagnoses.
CREATE TABLE p0 AS
SELECT i AS patient_id,
       CASE WHEN x < 0.20 THEN 'diabetes' WHEN x < 0.32 THEN 'cardiovascular'
            WHEN x < 0.37 THEN 'renal' WHEN x < 0.47 THEN 'respiratory'
            WHEN x < 0.60 THEN 'infection' WHEN x < 0.72 THEN 'dengue'
            WHEN x < 0.85 THEN 'obstetric' WHEN x < 0.92 THEN 'injury'
            ELSE 'surgical' END AS profile,
       u(i, 'state') AS u_state, u(i, 'district') AS u_district, u(i, 'age') AS ua
FROM (SELECT i, u(i, 'profile') AS x FROM range(1, coalesce(getvariable('patients'), 58000) + 1) t(i));

CREATE TABLE p1 AS
SELECT p0.*, s.state, s.hospitals,
       profile = 'obstetric' OR (profile <> 'obstetric' AND u(patient_id, 'sex') < 0.48) AS female,
       greatest(1, CASE profile
         WHEN 'diabetes' THEN 35 + 50 * ua ^ 0.9
         WHEN 'cardiovascular' THEN 40 + 50 * ua
         WHEN 'renal' THEN 30 + 55 * ua
         WHEN 'respiratory' THEN CASE WHEN ua < 0.3 THEN 1 + ua * 36 ELSE 20 + 65 * ua END
         WHEN 'infection' THEN 90 * ua
         WHEN 'dengue' THEN 5 + 60 * ua
         WHEN 'obstetric' THEN 18 + 24 * ua
         WHEN 'injury' THEN 5 + 85 * ua
         ELSE 10 + 70 * ua END) AS age
FROM p0 ASOF JOIN ref_state s ON p0.u_state >= s.lo;

CREATE TABLE p2 AS
SELECT p1.*, d.district,
       -- C4 reads 1970-01-01 as a placeholder (DT05), so nobody is born on it.
       CASE WHEN DATE '2017-07-01' - floor(age * 365.25 + u(patient_id, 'dob') * 365)::INTEGER = DATE '1970-01-01'
            THEN DATE '1970-01-02'
            ELSE DATE '2017-07-01' - floor(age * 365.25 + u(patient_id, 'dob') * 365)::INTEGER END AS dob,
       pick(d.postcodes, u(patient_id, 'postcode')) AS postcode,
       CASE WHEN u(patient_id, 'born_here') < 0.85 THEN p1.state
            ELSE pick((SELECT list(state ORDER BY state) FROM ref_pb), u(patient_id, 'born_state')) END AS birth_state
FROM p1 ASOF JOIN ref_district d ON p1.state = d.state AND p1.u_district >= d.lo;

CREATE TABLE p3 AS
SELECT p2.*,
       CASE WHEN u(patient_id, 'pb') < 0.6 THEN b.codes[1]
            ELSE pick(b.codes, u(patient_id, 'pb_alt')) END AS pb,
       u(patient_id, 'ethnic') AS ue
FROM p2 JOIN ref_pb b ON b.state = p2.birth_state;

-- The serial 9##G is unique within (dob, pb, sex): 100 x 5 slots per group.
CREATE TABLE patient AS
WITH s AS (
  SELECT p3.*,
         (hash(dob, pb, female) % 500 + row_number() OVER (PARTITION BY dob, pb, female ORDER BY patient_id) - 1) % 500 AS slot
  FROM p3
)
SELECT patient_id,
       strftime(dob, '%y%m%d') || '-' || pb || '-9' || lpad((slot // 5)::VARCHAR, 2, '0')
         || ((slot % 5) * 2 + CASE WHEN female THEN 0 ELSE 1 END)::VARCHAR AS mykad,
       CASE
         WHEN ue < 0.65 THEN
           CASE WHEN female THEN pick(tokens('malay_f'), u(patient_id, 'given')) || ' BINTI '
                ELSE pick(tokens('malay_m'), u(patient_id, 'given')) || ' BIN ' END
           || pick(tokens('malay_m'), u(patient_id, 'father'))
         WHEN ue < 0.90 THEN
           pick(tokens('chinese_surname'), u(patient_id, 'surname')) || ' '
           || pick(tokens('chinese_given'), u(patient_id, 'given')) || ' '
           || pick(tokens('chinese_given'), u(patient_id, 'given2'))
         ELSE
           CASE WHEN female THEN pick(tokens('indian_f'), u(patient_id, 'given')) || ' A/P '
                ELSE pick(tokens('indian_m'), u(patient_id, 'given')) || ' A/L ' END
           || pick(tokens('indian_m'), u(patient_id, 'father'))
       END AS name,
       CASE WHEN female THEN 'F' ELSE 'M' END AS sex,
       dob, state, district, postcode,
       'NO ' || (1 + floor(u(patient_id, 'house') * 120))::INTEGER || ', JALAN '
         || pick(tokens('street'), u(patient_id, 'street')) || ' '
         || (1 + floor(u(patient_id, 'jalan') * 12))::INTEGER AS address,
       -- carried to the admission step, not written out
       profile, age, hospitals
FROM s;

-- ----------------------------------------------------------------- admissions
-- n_adm admissions per patient; the first in 2017–2021 (2017 is quieter, so
-- the Warm-up extract stays near 5k), the rest after exponential gaps.
CREATE TABLE a0 AS
SELECT patient_id, profile, age, hospitals, state, district, sex, dob,
       unnest(range(1, n_adm + 1)) AS k, n_adm, first_day
FROM (
  SELECT *,
    1 + CASE profile
      WHEN 'diabetes' THEN floor(8 * u(patient_id, 'n') ^ 1.4)
      WHEN 'cardiovascular' THEN floor(6 * u(patient_id, 'n') ^ 1.4)
      WHEN 'renal' THEN floor(8 * u(patient_id, 'n') ^ 1.2)
      WHEN 'respiratory' THEN floor(4 * u(patient_id, 'n') ^ 1.6)
      WHEN 'dengue' THEN 0
      WHEN 'obstetric' THEN (u(patient_id, 'n') < 0.2)::INTEGER
      WHEN 'infection' THEN (u(patient_id, 'n') < 0.15)::INTEGER
      ELSE (u(patient_id, 'n') < 0.12)::INTEGER END::INTEGER AS n_adm,
    make_date(
      CASE WHEN y < 0.065 THEN 2017 ELSE 2018 + least(3, floor((y - 0.065) / (0.935 / 4)))::INTEGER END,
      1, 1)
    + CASE WHEN profile = 'dengue' AND u(patient_id, 'season') < 0.6
           THEN CASE WHEN u(patient_id, 'peak') < 0.5 THEN 0 ELSE 150 END + floor(u(patient_id, 'day') * 90)
           ELSE floor(u(patient_id, 'day') * 365) END::INTEGER AS first_day
  FROM (SELECT *, u(patient_id, 'year') AS y FROM patient)
);

-- Diagnosis group and length of stay; transfer candidates.
CREATE TABLE a1 AS
SELECT a0.*,
  CASE
    WHEN uk(patient_id, k, 'own') < CASE WHEN profile IN ('diabetes', 'cardiovascular', 'renal', 'respiratory') THEN 0.7
                                         WHEN k = 1 THEN 0.9 ELSE 0.6 END
      THEN profile
    ELSE pick(['infection', 'respiratory', 'surgical', 'injury', 'cardiovascular'], uk(patient_id, k, 'other'))
  END AS grp,
  k >= 2 AND hospitals >= 2 AND uk(patient_id, k, 'transfer') < 0.05 AS cand
FROM a0;

CREATE TABLE a2 AS
SELECT a1.*,
  least(60, floor(expo(uk(patient_id, k, 'los'), CASE grp
    WHEN 'dengue' THEN 3 WHEN 'diabetes' THEN 4 WHEN 'cardiovascular' THEN 5 WHEN 'renal' THEN 5
    WHEN 'respiratory' THEN 4 WHEN 'infection' THEN 4 WHEN 'obstetric' THEN 2
    WHEN 'injury' THEN 7 ELSE 3 END)))::INTEGER AS los_raw
FROM a1;

CREATE TABLE a3 AS
SELECT a2.*,
  cand AND NOT coalesce(lag(cand) OVER w, false) AND coalesce(lag(los_raw) OVER w, 0) >= 1 AS is_transfer
FROM a2 WINDOW w AS (PARTITION BY patient_id ORDER BY k);

-- Gap from the previous discharge: shorter for older patients and after longer
-- stays (the mild planted readmission effects). A transfer starts on the
-- previous discharge day, so it needs a previous stay of at least one night.
CREATE TABLE a4 AS
SELECT *,
  first_day + (sum(step) OVER (PARTITION BY patient_id ORDER BY k))::INTEGER AS admit_day
FROM (
  SELECT x.*,
    CASE WHEN k = 1 THEN 0
         ELSE greatest(1, lag(los) OVER w + CASE WHEN is_transfer THEN 0 ELSE
           1 + floor(expo(uk(patient_id, k, 'gap'),
                 CASE profile WHEN 'diabetes' THEN 150 WHEN 'cardiovascular' THEN 160
                              WHEN 'renal' THEN 120 WHEN 'respiratory' THEN 200 ELSE 300 END
                 * (1.15 - 0.4 * age / 90)
                 * (1 - 0.2 * least(lag(los) OVER w, 14) / 14)))::INTEGER END)
    END AS step
  FROM (SELECT *, CASE WHEN is_transfer THEN greatest(los_raw, 1) ELSE los_raw END AS los FROM a3) x
  WINDOW w AS (PARTITION BY patient_id ORDER BY k)
);

-- Keep 2017–2021 and set times. Day cases are admitted 07:00–11:59 and leave
-- 2–8 hours later; others leave 09:00–17:59. A transfer arrives 30–180 minutes
-- after the previous discharge.
CREATE TABLE a5 AS
WITH kept AS (
  FROM a4 WHERE admit_day <= DATE '2021-12-31'
),
t AS (
  SELECT kept.*,
    admit_day + to_minutes(CASE WHEN los = 0 THEN 420 + floor(uk(patient_id, k, 'in') * 300)
                                ELSE floor(uk(patient_id, k, 'in') * 1440) END::BIGINT) AS admit_nt,
    CASE WHEN los = 0
         THEN admit_day + to_minutes((420 + floor(uk(patient_id, k, 'in') * 300)
                                      + 120 + floor(uk(patient_id, k, 'out') * 360))::BIGINT)
         ELSE admit_day + los + to_minutes((540 + floor(uk(patient_id, k, 'out') * 540))::BIGINT) END AS discharge_ts
  FROM kept
)
SELECT t.*,
  CASE WHEN is_transfer
       THEN lag(discharge_ts) OVER w + to_minutes((30 + floor(uk(patient_id, k, 'arrive') * 150))::BIGINT)
       ELSE admit_nt END AS admit_ts,
  coalesce(lead(is_transfer) OVER w, false) AS transferred_out,
  k = n_adm AS last_generated
FROM t WINDOW w AS (PARTITION BY patient_id ORDER BY k);

-- Facility: a hospital in the residence state, weighted by size and 8x for the
-- patient's own district. A transfer goes to another hospital, usually a referral one.
-- Each pick is the first hospital, in facility_code order, whose running weight
-- passes floor(draw x total weight). The running weights depend only on the
-- residence (or, for a transfer, the hospital it leaves), so they are worked out
-- once per residence and each admission finds its hospital with an ASOF join;
-- that keeps the large dataset (build.sh large) linear in the admissions.
CREATE TABLE home_weight AS
WITH w AS (
  SELECT d.state, d.district, h.facility_code,
         h.size_weight * CASE WHEN h.district = d.district THEN 8 ELSE 1 END AS w
  FROM (SELECT DISTINCT state, district FROM a5) d JOIN ref_hospital h ON h.state = d.state
)
SELECT state, district, facility_code,
       sum(w) OVER (PARTITION BY state, district ORDER BY facility_code) - w AS cum_before,
       sum(w) OVER (PARTITION BY state, district) AS total
FROM w;

CREATE TABLE pick_home AS
WITH a AS (
  SELECT a5.patient_id, a5.k, a5.state, a5.district,
         floor(uk(a5.patient_id, a5.k, 'facility') * t.total) AS threshold
  FROM a5 JOIN (SELECT DISTINCT state, district, total FROM home_weight) t USING (state, district)
)
SELECT a.patient_id, a.k, w.facility_code
FROM a ASOF JOIN home_weight w
  ON w.state = a.state AND w.district = a.district AND a.threshold >= w.cum_before;

CREATE TABLE transfer_weight AS
WITH w AS (
  SELECT f.facility_code AS from_code, f.state, h.facility_code,
         h.size_weight * CASE WHEN h.is_referral THEN 4 ELSE 1 END AS w
  FROM ref_hospital f JOIN ref_hospital h ON h.state = f.state AND h.facility_code <> f.facility_code
)
SELECT from_code, state, facility_code,
       sum(w) OVER (PARTITION BY from_code ORDER BY facility_code) - w AS cum_before,
       sum(w) OVER (PARTITION BY from_code) AS total
FROM w;

CREATE TABLE pick_transfer AS
WITH a AS (
  SELECT a5.patient_id, a5.k, prev.facility_code AS from_code,
         floor(uk(a5.patient_id, a5.k, 'to') * t.total) AS threshold
  FROM a5
  JOIN pick_home prev ON prev.patient_id = a5.patient_id AND prev.k = a5.k - 1
  JOIN (SELECT DISTINCT from_code, state, total FROM transfer_weight) t
    ON t.from_code = prev.facility_code AND t.state = a5.state
  WHERE a5.is_transfer
)
SELECT a.patient_id, a.k, w.facility_code
FROM a ASOF JOIN transfer_weight w
  ON w.from_code = a.from_code AND a.threshold >= w.cum_before;

CREATE TABLE a6 AS
SELECT a5.*, coalesce(t.facility_code, h.facility_code) AS facility_code,
       pick(d.codes, uk(a5.patient_id, a5.k, 'code')) AS principal_dx,
       date_diff('year', a5.dob, a5.admit_day) AS age_at_admit
FROM a5
JOIN pick_home h USING (patient_id, k)
LEFT JOIN pick_transfer t USING (patient_id, k)
JOIN ref_dx d ON d.grp = a5.grp;

-- admission_id follows admit_ts (a patient never has two admissions at one
-- time). Numbered on a narrow table: one window over every wide admission row
-- does not fit in memory at the large scale.
CREATE TABLE admission_order AS
SELECT patient_id, k, row_number() OVER (ORDER BY admit_ts, patient_id) AS admission_id
FROM a6;

CREATE TABLE admission AS
WITH s AS (
  SELECT a6.*,
    [CASE WHEN profile = 'diabetes' AND grp <> 'diabetes' AND uk(patient_id, k, 's1') < 0.85 THEN 'E11.9'
          WHEN profile = 'diabetes' AND grp = 'diabetes' AND uk(patient_id, k, 's1') < 0.5 THEN 'I10' END,
     CASE WHEN age_at_admit >= 50 AND uk(patient_id, k, 's2') < 0.35
          THEN pick(['I10', 'I11.9', 'N18.3', 'J44.9', 'I50.9'], uk(patient_id, k, 's2c')) END,
     CASE WHEN uk(patient_id, k, 's3') < 0.08
          THEN pick(['A09.9', 'N39.0', 'J18.9'], uk(patient_id, k, 's3c')) END] AS cand_dx
  FROM a6
)
SELECT o.admission_id,
       patient_id,
       'RN' || lpad(((patient_id * 7919 + hash(facility_code) % 10000000) % 10000000)::VARCHAR, 7, '0') AS mrn,
       facility_code, admit_ts, discharge_ts, principal_dx,
       list_filter(cand_dx, lambda x, i: x IS NOT NULL AND x <> principal_dx
                                         AND list_position(cand_dx, x) = i) AS secondary_dx,
       CASE
         WHEN transferred_out THEN 'TRANSFERRED'
         WHEN last_generated AND uk(patient_id, k, 'death') <
              CASE WHEN grp IN ('obstetric', 'dengue') THEN 0.002
                   WHEN grp IN ('cardiovascular', 'renal', 'infection') THEN 0.02 + 0.10 * (age_at_admit / 90) ^ 2
                   ELSE 0.01 + 0.04 * (age_at_admit / 90) ^ 2 END THEN 'DIED'
         WHEN uk(patient_id, k, 'aor') < 0.02 THEN 'AOR'
         ELSE 'DISCHARGED'
       END AS discharge_status,
       CASE WHEN age_at_admit < 12 THEN 'PAEDIATRIC'
            WHEN grp = 'obstetric' THEN 'O&G'
            WHEN grp = 'injury' THEN 'ORTHOPAEDIC'
            WHEN grp = 'surgical' THEN 'SURGICAL'
            WHEN (principal_dx LIKE 'I21%' OR principal_dx LIKE 'A41%') AND uk(patient_id, k, 'icu') < 0.3 THEN 'ICU'
            ELSE 'MEDICAL' END AS ward,
       CASE WHEN is_transfer THEN 'TRANSFER'
            WHEN grp IN ('surgical', 'obstetric') AND uk(patient_id, k, 'elective') < 0.4 THEN 'ELECTIVE'
            ELSE 'EMERGENCY' END AS admission_type
FROM s JOIN admission_order o USING (patient_id, k);

ALTER TABLE patient DROP COLUMN profile;
ALTER TABLE patient DROP COLUMN age;
ALTER TABLE patient DROP COLUMN hospitals;

COPY (FROM patient ORDER BY patient_id)
  TO 'generator/truth/patient.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM admission ORDER BY admission_id)
  TO 'generator/truth/admission.parquet' (FORMAT parquet, COMPRESSION zstd);
