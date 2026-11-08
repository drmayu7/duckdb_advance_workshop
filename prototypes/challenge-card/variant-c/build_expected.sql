-- PROTOTYPE. Variant C: facilitator runs this once when building the Offline bundle.
-- The expected tables double as checkpoints: a Participant who is stuck loads one and carries on.
.read solution.sql
COPY ch13_readmit           TO 'variant-c/expected/ch13_readmit.parquet';
COPY ch13_readmit_unplanned TO 'variant-c/expected/ch13_readmit_unplanned.parquet';
COPY ch13_by_state          TO 'variant-c/expected/ch13_by_state.parquet';
