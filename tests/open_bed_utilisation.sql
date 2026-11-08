-- MoH bed utilisation: 149 hospital names, 130 matching the facility list exactly.
SELECT assert_eq('149 hospital names', count(DISTINCT hospital), 149)
FROM read_csv('data/open/bed_utilisation.csv');

SELECT assert_eq('130 exact name matches', count(*), 130)
FROM read_csv('data/open/bed_utilisation.csv') b
JOIN read_json('data/open/facilities.json') f
  ON upper(b.hospital) = f.NAMA AND f.KATEGORI_FASILITI = 'HOSPITAL';
