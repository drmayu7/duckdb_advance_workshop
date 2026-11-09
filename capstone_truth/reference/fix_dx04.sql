-- DQ FIX: DX04 (Angle B). Some principal diagnoses are typed as free text in
-- Malay or English ("Demam denggi", "Dengue with warning signs", "Pneumonia")
-- instead of an ICD-10 code. norm_icd() cannot make a code of them, so they
-- join no ref_icd10 row and drop out of scenario_group = 'dengue': 2021 dengue
-- per 100k falls in every state. Map each text to its code, in the RAW stage,
-- before C4. Runs on admission_raw.
--
-- How a team finds it: C5's check (principal diagnoses that normalise to no
-- ref_icd10 code, want 0 rows) lists them; there is no digit in them.
CREATE OR REPLACE TABLE dx_text (text_key VARCHAR, icd10 VARCHAR);
INSERT INTO dx_text VALUES
  ('DEMAM DENGGI', 'A97.0'), ('DENGUE FEVER', 'A97.0'), ('DENGUE WITHOUT WARNING SIGNS', 'A97.0'),
  ('DENGGI DENGAN TANDA AMARAN', 'A97.1'), ('DENGGI DGN TANDA AMARAN', 'A97.1'), ('DENGUE WITH WARNING SIGNS', 'A97.1'),
  ('DENGGI TERUK', 'A97.2'), ('DEMAM DENGGI BERDARAH', 'A97.2'), ('SEVERE DENGUE', 'A97.2'),
  ('DENGGI', 'A97.9'), ('DENGUE', 'A97.9'),
  ('RADANG PARU-PARU', 'J18.9'), ('PNEUMONIA', 'J18.9'),
  ('CIRIT-BIRIT', 'A09.9'), ('GASTROENTERITIS AKUT', 'A09.9'), ('GASTROENTERITIS', 'A09.9'),
  ('ACUTE GASTROENTERITIS', 'A09.9'), ('AGE', 'A09.9'),
  ('JANGKITAN SALURAN KENCING', 'N39.0'), ('URINARY TRACT INFECTION', 'N39.0'), ('UTI', 'N39.0');

UPDATE admission_raw
SET principal_dx = t.icd10
FROM dx_text t
WHERE upper(trim(admission_raw.principal_dx)) = t.text_key;

-- Every principal diagnosis now has a digit (want 0 rows).
SELECT principal_dx, count(*) AS n FROM admission_raw
WHERE NOT regexp_matches(principal_dx, '\d') GROUP BY ALL;
