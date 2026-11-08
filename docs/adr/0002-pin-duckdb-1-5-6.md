# Pin Series 2 to DuckDB 1.5.6, not 2.0.0 LTS

Series 2 runs 11–13 Nov 2026, three weeks after DuckDB 2.0.0 LTS was released (21 Oct). Every Participant installs DuckDB 1.5.6, and the Offline bundle ships 1.5.6 extensions. On 2.0.0, `PIVOT` inside a CTE is broken until 2.0.1 (18 Nov, after the workshop), `rapidfuzz` has moved to a separate repository, Python relations have lost `fetchone()`, and some extensions have no build yet. 1.5.6 is supported until 1 Mar 2027.

## Considered options

- **2.0.0 LTS**: current and long-term supported, but it breaks Core content (`PIVOT` in CTEs) and one Extension track (name matching).
- **1.5.6** (chosen): stable for everything on the Programme.

## Consequences

- Materials use only syntax that also runs on 2.0: `lambda x: …`, never the arrow form `x -> …`, and no reliance on `//` or `%` by zero returning NULL.
- Data is shared as Parquet, never as `.duckdb` files: files written by 2.0 can't be read by 1.5.x, and the R take-home notebooks must run on 2.0.0 because CRAN only ships that version.
- The closing session includes a short "what changes in DuckDB 2.0" segment so Participants can upgrade after the workshop.
