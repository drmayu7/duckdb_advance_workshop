-- MoH facility list, re-serialised as JSON with its real mess kept (ADR 0003).
SELECT assert_eq('hospitals', count(*), 166)
FROM read_json('data/open/facilities.json')
WHERE KATEGORI_FASILITI = 'HOSPITAL';

SELECT assert_eq('state spellings', count(DISTINCT NEGERI), 17)
FROM read_json('data/open/facilities.json');

SELECT assert_eq('merged KL/Putrajaya pseudo-state kept',
                 count(*) > 0, true)
FROM read_json('data/open/facilities.json')
WHERE NEGERI = 'WILAYAH PERSEKUTUAN KUALA LUMPUR DAN PUTRAJAYA';

SELECT assert_eq('hospital names with embedded newlines', count(*), 6)
FROM read_json('data/open/facilities.json')
WHERE KATEGORI_FASILITI = 'HOSPITAL' AND contains(NAMA, chr(10));

SELECT assert_eq('postcodes keep leading zeros (VARCHAR)',
                 typeof(any_value(POSKOD)), 'VARCHAR')
FROM read_json('data/open/facilities.json');
