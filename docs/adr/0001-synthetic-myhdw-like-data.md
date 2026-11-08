# Use a synthetic MyHDW-like dataset, not real MyHDW data

The official Programme describes the Capstone as working from "raw MyHDW data", but every Series 2 exercise, demo and Capstone uses a synthetic MyHDW-like dataset, optionally enriched with Malaysian open data. Real MyHDW extracts contain patient-level health data covered by PDPA and KKM data governance, and would end up on personal laptops, in a public GitHub repo and on a public S3 bucket. Synthetic data keeps the realistic shape (patients, admissions, diagnoses, facilities, states) and the deliberate messiness the wrangling modules need, with no privacy risk.

## Consequences

- The dataset generator decides what kinds of messiness exist, so cleaning exercises are designed together with the generator rather than discovered in real data.
- Participants should be told explicitly that the data is synthetic, so no one reads clinical meaning into the results.
