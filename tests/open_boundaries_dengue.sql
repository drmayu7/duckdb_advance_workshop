-- DOSM boundaries (frozen 2022 copies) and the wide archived dengue CSV.
SELECT assert_eq('16 state polygons', len(features), 16)
FROM read_json('data/open/geo_state.geojson');

SELECT assert_eq('160 district polygons', len(features), 160)
FROM read_json('data/open/geo_district.geojson');

CREATE TABLE dengue AS FROM read_csv('data/open/dengue_state_age_2018_2021.csv');
SELECT assert_eq('dengue years', list(DISTINCT TAHUN ORDER BY TAHUN), [2018, 2019, 2020, 2021]) FROM dengue;
SELECT assert_eq('dengue is wide: 15 state columns',
                 (SELECT count(*) FROM (DESCRIBE dengue)) - 2, 15);
