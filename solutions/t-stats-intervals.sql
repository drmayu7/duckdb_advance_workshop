-- Reveal: Extension track "Statistics for health data" (cards/t-stats-intervals.md).
-- Run from the bundle folder, in your Work database, after C9 (or the C8 and C9 Checkpoints).

-- stats_duck is a community extension: it never loads by itself, so LOAD it first.
LOAD stats_duck;

-- Look first: the R-style quantile functions. qnorm(0.975) is the 1.96 of a 95% interval.
SELECT qnorm(0.975) AS z, pnorm(1.96) AS p;

-- Core, part 1: a 95% Wilson (score) interval for each state's readmission rate.
-- With p = readmissions / index_episodes, n = index_episodes and z = qnorm(0.975):
--   centre = (p + z^2 / 2n) / (1 + z^2 / n)
--   half   = z * sqrt(p (1 - p) / n + z^2 / 4n^2) / (1 + z^2 / n)
-- It is R's prop.test(x, n, correct = FALSE)$conf.int.
CREATE OR REPLACE TABLE readmit_ci AS
WITH w AS (
  SELECT *, readmissions / index_episodes AS p, index_episodes AS n, qnorm(0.975) AS z
  FROM readmit_state
),
wilson AS (
  SELECT *, (p + z ^ 2 / (2 * n)) / (1 + z ^ 2 / n) AS centre,
            z * sqrt(p * (1 - p) / n + z ^ 2 / (4 * n ^ 2)) / (1 + z ^ 2 / n) AS half
  FROM w
)
SELECT state, index_episodes, readmissions, readmit_pct,
       round(100 * (centre - half), 1) AS ci_low_pct,
       round(100 * (centre + half), 1) AS ci_high_pct
FROM wilson;

-- Check one number against R before you trust a young extension:
-- prop.test(533, 3378, correct = FALSE)$conf.int is 0.146 to 0.170, Selangor's row.
FROM readmit_ci WHERE state = 'SELANGOR';

-- The small states have the widest intervals: Putrajaya's 20.4% is 49 episodes.
SELECT state, index_episodes, readmit_pct, ci_low_pct, ci_high_pct, ci_high_pct - ci_low_pct AS width
FROM readmit_ci
ORDER BY width DESC;

-- Core, part 2: do diabetes episodes stay longer than dengue ones? ttest_2samp is an
-- aggregate over two columns: each row gives its LOS to the column of its group and
-- NULL to the other, so one pass over episode holds both samples. Welch's test.
WITH g AS (
  SELECT e.los_days, i.scenario_group
  FROM episode e JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = e.principal_dx
  WHERE i.scenario_group IN ('diabetes', 'dengue')
)
SELECT t.mean_diff, t.ci_lower, t.ci_upper, t.p_value, t.df
FROM (SELECT ttest_2samp(CASE WHEN scenario_group = 'diabetes' THEN los_days END,
                         CASE WHEN scenario_group = 'dengue' THEN los_days END) AS t
      FROM g);

-- Stretch S1: the exact (Clopper-Pearson) interval, R's binom.test, from qbeta.
-- It is a little wider than Wilson's, most of all for the small states.
SELECT state, readmissions, index_episodes, ci_low_pct, ci_high_pct,
       round(100 * CASE WHEN readmissions = 0 THEN 0 ELSE qbeta(0.025, readmissions, index_episodes - readmissions + 1) END, 1) AS exact_low_pct,
       round(100 * CASE WHEN readmissions = index_episodes THEN 1 ELSE qbeta(0.975, readmissions + 1, index_episodes - readmissions) END, 1) AS exact_high_pct
FROM readmit_ci
ORDER BY state;

-- Stretch S2: which states' intervals leave out the national rate?
WITH national AS (SELECT round(100 * sum(readmissions) / sum(index_episodes), 1) AS pct FROM readmit_ci)
SELECT state, readmit_pct, ci_low_pct, ci_high_pct, national.pct AS national_pct,
       NOT national.pct BETWEEN ci_low_pct AND ci_high_pct AS differs
FROM readmit_ci, national
ORDER BY differs DESC, state;

-- Stretch S3: a clinical "Table 1" of LOS and age by diagnosis group.
CREATE OR REPLACE TABLE los_groups AS
SELECT e.los_days, e.age, e.sex, i.scenario_group
FROM episode e JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = e.principal_dx
WHERE i.scenario_group IN ('diabetes', 'dengue');
FROM table_one('los_groups', variables := ['los_days', 'age', 'sex'], by := ['scenario_group']);
