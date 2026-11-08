-- Curated WHO ICD-10 subset with the Scenario's grouping.
CREATE TABLE icd AS FROM read_csv('data/open/ref_icd10.csv');

SELECT assert_eq('about 150 codes', count(*) BETWEEN 120 AND 200, true) FROM icd;
SELECT assert_eq('codes are unique', count(DISTINCT icd10), count(*)) FROM icd;
SELECT assert_eq('every code has a scenario_group', count(*) FILTER (scenario_group IS NULL), 0) FROM icd;
SELECT assert_eq('every code is attributed to WHO', count(*) FILTER (source NOT LIKE 'WHO ICD-10 %'), 0) FROM icd;

SELECT assert_eq('dengue group',
                 list(icd10 ORDER BY icd10),
                 ['A90', 'A91', 'A97.0', 'A97.1', 'A97.2', 'A97.9'])
FROM icd WHERE scenario_group = 'dengue';

SELECT assert_eq('diabetes group is exactly E10-E14',
                 bool_and(icd10 SIMILAR TO 'E1[0-4](\..)?') AND count(*) > 0, true)
FROM icd WHERE scenario_group = 'diabetes';
SELECT assert_eq('no E10-E14 code outside diabetes', count(*), 0)
FROM icd WHERE icd10 SIMILAR TO 'E1[0-4].*' AND scenario_group <> 'diabetes';
