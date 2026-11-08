-- Prepended to every tests/*.sql by `build.sh test`.
-- A test fails when any statement errors; assert_eq raises a readable error.
.bail on
.mode list
.headers off
SET autoinstall_known_extensions = false;
SET autoload_known_extensions = false;
CREATE MACRO assert_eq(check_name, actual, expected) AS
  CASE WHEN actual IS NOT DISTINCT FROM expected
       THEN check_name || ': ok'
       ELSE error(check_name || ': expected ' || coalesce(expected::VARCHAR, 'NULL')
                  || ', got ' || coalesce(actual::VARCHAR, 'NULL'))
  END;
