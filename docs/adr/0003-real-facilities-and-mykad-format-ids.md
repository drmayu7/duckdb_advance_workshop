# Use real MoH facilities and MyKad-format identifiers in the public synthetic dataset

The MyHDW-like dataset (ADR 0001) pairs synthetic admissions with the **real** MoH facility list, and gives synthetic patients **MyKad-format** identification numbers. Both are published on a public repo and a public S3 bucket. We accept this because the facility list's real mess (17 state spellings, newlines inside names, health districts that don't match DOSM districts, 130 of 149 exact name matches against the bed-utilisation file) gives free, authentic cleaning and name-matching Challenges. MyKad structure (date of birth, place-of-birth code, sex parity) is what MyHDW staff validate and de-duplicate on every day. Two safeguards keep this acceptable:

- Every synthetic IC has a valid date of birth and place-of-birth code, but its last four digits always start with `9` (`YYMMDD-PB-9##G`). That makes workshop ICs recognisable, still parseable, and less likely to equal a real person's number. It does not guarantee no real IC is ever matched.
- The dataset README, every Challenge card and the Capstone template carry a "synthetic data, not real hospital performance" banner, because slides and talks will show synthetic readmission rates next to real KKM hospital names.

## Considered options

- **Fictional hospitals**: no reputational risk to real facilities, but we lose the real cleaning work and the name-matching Extension track, and would have to fake the mess instead.
- **Hospital MRN only, no MyKad**: no IC-collision risk, but drops the six MyKad defects and makes patient de-duplication unrealistic for this audience.
- **Fully random valid MyKad**: same teaching value, but without the `9###` marker a collision with a real person looks no different from any other IC.

## Consequences

- The generator must enforce the `9###` serial pattern. The MyKad Self-checks and `norm_mykad()` must not reject it.
- If the dataset is ever shared beyond the workshop, these choices should be reviewed with KKM data governance first.
