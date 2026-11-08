-- DOSM population (in thousands) covers every state, at state and district level.
CREATE TABLE states AS
  SELECT unnest(features).properties.state AS state
  FROM read_json('data/open/geo_state.geojson');

SELECT assert_eq('16 states in the boundaries', count(*), 16) FROM states;

SELECT assert_eq('every state in state population', count(*), 0)
FROM states ANTI JOIN 'data/open/population_state.parquet' p USING (state);

SELECT assert_eq('every state in district population', count(*), 0)
FROM states ANTI JOIN 'data/open/population_district.parquet' p USING (state);

SELECT assert_eq('state population covers 2018-2021',
                 count(DISTINCT year(date)) FILTER (year(date) BETWEEN 2018 AND 2021), 4)
FROM 'data/open/population_state.parquet';

SELECT assert_eq('district population has 2020', count(*) > 0, true)
FROM 'data/open/population_district.parquet' WHERE year(date) = 2020;
