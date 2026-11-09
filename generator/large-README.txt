DuckDB Workshop Series 2: large dataset (2018-2021)

> **Synthetic data, not real hospital performance.** Patients and admissions are
> made up. The hospital names are real, so no number here says anything about a
> real hospital.

About 30 million clean admissions, 2018-2021, from the same generator as the
workshop's small dataset, with the same columns as its clean admission table:
admission_id, patient_id, mrn, facility_code, admit_ts, discharge_ts,
principal_dx, secondary_dx (a list of codes), discharge_status, ward,
admission_type. There are no data-quality defects in it.

  large/admission/year=YYYY/part-Q.parquet   one file per admit quarter
  large/patient.parquet                      every patient with an admission

The files are Hive-partitioned: `year` is in the folder name, not in the files,
and DuckDB adds it as a column. Unzip next to your bundle's data/ folder, so
that large/ sits in the bundle folder, then, in DuckDB 1.5.6:

  SELECT count(*) FROM 'large/admission/*/*.parquet';
  SELECT year, count(*) FROM 'large/admission/*/*.parquet' GROUP BY ALL ORDER BY year;
  FROM 'large/admission/*/*.parquet' a JOIN 'large/patient.parquet' p USING (patient_id) LIMIT 5;

The facilitator's demos (demos/m1/csv-vs-parquet.sql and demos/m3/s3-demo.sql)
read these same paths. The S3 demo reads them from a private bucket; to try it
at home, read the local large/ folder instead.
