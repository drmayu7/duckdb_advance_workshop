-- Peer-review results (#10), live at 2.45 on Day 3. Over lunch, type each score
-- slip into capstone/scores.csv: two rows per slip (one per team scored), with
-- the slip's number, the scorer's team, the team scored, the four scores (1-4)
-- and "one thing this team did well". Then, from the bundle folder:
--   .read capstone/scores.sql
-- The scores are formative: averages only, no ranking, and correctness (the
-- capstone_truth/ diff) is reported apart from them.

CREATE OR REPLACE TEMP TABLE scores AS
FROM read_csv('capstone/scores.csv', header = true,
              columns = {'slip': 'INTEGER', 'scorer_team': 'VARCHAR', 'team': 'VARCHAR',
                         'answer': 'INTEGER', 'dq_story': 'INTEGER', 'pipeline': 'INTEGER',
                         'communication': 'INTEGER', 'did_well': 'VARCHAR'});

-- 1. Rows that can't be right, to correct in scores.csv before the results
--    (want 0 rows). They are left out of the averages below.
CREATE OR REPLACE TEMP TABLE problems AS
SELECT 'team scored itself' AS problem, slip, scorer_team, team FROM scores WHERE upper(scorer_team) = upper(team)
UNION ALL
SELECT 'score outside 1-4', slip, scorer_team, team FROM scores
WHERE NOT (answer BETWEEN 1 AND 4 AND dq_story BETWEEN 1 AND 4 AND pipeline BETWEEN 1 AND 4 AND communication BETWEEN 1 AND 4)
   OR answer IS NULL OR dq_story IS NULL OR pipeline IS NULL OR communication IS NULL;
FROM problems ORDER BY slip, team;

-- 2. Each team's average per criterion, over the slips that scored it.
SELECT team, count(*) AS slips,
       round(avg(answer), 1) AS answer,
       round(avg(dq_story), 1) AS dq_story,
       round(avg(pipeline), 1) AS pipeline,
       round(avg(communication), 1) AS communication
FROM scores
WHERE (slip, team) NOT IN (SELECT (slip, team) FROM problems)
GROUP BY team
ORDER BY team;

-- 3. One thing each team did well: pick one per team to read out.
SELECT team, did_well FROM scores WHERE did_well IS NOT NULL ORDER BY team, slip;
