-- The large dataset (#25): every clean 2018–2021 admission, for the facilitator's
-- CSV-vs-Parquet demo (demos/m1/) and live S3 demo (demos/m3/). Runs after
-- truth.sql in the same session, from a scratch root; `build.sh large` sets the
-- `patients` variable first (16,585,000 gives about 30M admissions) and moves
-- large/ to where it belongs. It is the small truth's generator at a bigger
-- scale, so patients 1–58000 and their admissions are the small truth's own.
--
-- Layout: Hive-partitioned by `year` (the folder name, not a column in the
-- files), one file per admit quarter, so a filter on year scans 4 of 16 files:
--   large/admission/year=YYYY/part-Q.parquet
--   large/patient.parquet    (every patient with a 2018–2021 admission)
-- Each file is written sorted by its key in one COPY, so reruns are byte-identical.

CREATE TABLE large_admission AS
SELECT *, year(admit_ts) AS y, quarter(admit_ts) AS q
FROM admission
WHERE year(admit_ts) BETWEEN 2018 AND 2021;

CREATE MACRO large_part(yr, qr) AS TABLE
  SELECT * EXCLUDE (y, q) FROM large_admission WHERE y = yr AND q = qr ORDER BY admission_id;

COPY (FROM large_part(2018, 1)) TO 'large/admission/year=2018/part-1.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2018, 2)) TO 'large/admission/year=2018/part-2.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2018, 3)) TO 'large/admission/year=2018/part-3.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2018, 4)) TO 'large/admission/year=2018/part-4.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2019, 1)) TO 'large/admission/year=2019/part-1.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2019, 2)) TO 'large/admission/year=2019/part-2.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2019, 3)) TO 'large/admission/year=2019/part-3.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2019, 4)) TO 'large/admission/year=2019/part-4.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2020, 1)) TO 'large/admission/year=2020/part-1.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2020, 2)) TO 'large/admission/year=2020/part-2.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2020, 3)) TO 'large/admission/year=2020/part-3.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2020, 4)) TO 'large/admission/year=2020/part-4.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2021, 1)) TO 'large/admission/year=2021/part-1.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2021, 2)) TO 'large/admission/year=2021/part-2.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2021, 3)) TO 'large/admission/year=2021/part-3.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM large_part(2021, 4)) TO 'large/admission/year=2021/part-4.parquet' (FORMAT parquet, COMPRESSION zstd);

COPY (FROM patient WHERE patient_id IN (SELECT patient_id FROM large_admission) ORDER BY patient_id)
  TO 'large/patient.parquet' (FORMAT parquet, COMPRESSION zstd);
