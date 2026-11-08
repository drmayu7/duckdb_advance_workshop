-- Installs every extension the workshop uses from the bundle's own repo/ folder,
-- with no internet, into your per-user DuckDB folder. start-workshop runs this
-- for you from the bundle folder; you never need to run it by hand.
--
-- ".bail off" keeps going past an error. If you once installed an extension from
-- the internet, its line here fails with "origin is different". That is harmless:
-- it is the same signed v1.5.6 file, and smoke_test.sql proves it loads.
.bail off
INSTALL ui FROM 'repo';
INSTALL httpfs FROM 'repo';
INSTALL aws FROM 'repo';
INSTALL spatial FROM 'repo';
INSTALL excel FROM 'repo';
INSTALL stats_duck FROM 'repo';
INSTALL rapidfuzz FROM 'repo';
INSTALL splink_udfs FROM 'repo';
INSTALL gsheets FROM 'repo';
