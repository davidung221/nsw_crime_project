--------------------------------------------
--- 03 VALIDATION CHECKS (after loading) ---
--------------------------------------------
-- Run after 04_load_and_populate.sql to confirm the load is complete and correct.
-- Expected results are in the comments. If a result differs, stop and investigate.
-- Checks that read the 105.9M-row suburbs table are slow; the rest are fast.


-- Q1. Row counts for every final table
-- Expected: offence_type 62 | nsw_incidents 23,436 | census 4,542 | seifa 4,320
--           suburb_year 8,967,680 | suburbs 105,930,720 (slow)
SELECT 'offence_type'  AS table_name, COUNT(*) AS row_count FROM offence_type
UNION ALL SELECT 'nsw_incidents', COUNT(*) FROM nsw_incidents
UNION ALL SELECT 'census',        COUNT(*) FROM census
UNION ALL SELECT 'seifa',         COUNT(*) FROM seifa
UNION ALL SELECT 'suburb_year',   COUNT(*) FROM suburb_year
UNION ALL SELECT 'suburbs',       COUNT(*) FROM suburbs;


-- Q2. Coverage: suburb-level incidents as a share of the NSW total
-- This is the check that found the truncated suburb file (66.5% coverage).
-- Expected: 21,284,357 of 21,365,765 = 99.6%. The gap is incidents with no suburb.
SELECT
    (SELECT SUM(incident_count) FROM suburb_year)   AS suburb_total,
    (SELECT SUM(incident_count) FROM nsw_incidents) AS nsw_total,
    ROUND((SELECT SUM(incident_count) FROM suburb_year) * 100.0
          / (SELECT SUM(incident_count) FROM nsw_incidents), 1) AS coverage_pct;


-- Q3. Every first letter of the alphabet is present
-- Expected: A to Z except X (no NSW suburb starts with X).
-- A missing run of letters means the file was cut off.
SELECT
    UPPER(LEFT(c.sal_name, 1)) AS first_letter,
    COUNT(DISTINCT sy.sal_code) AS suburbs
FROM suburb_year sy
JOIN census c ON sy.sal_code = c.sal_code
GROUP BY UPPER(LEFT(c.sal_name, 1))
ORDER BY first_letter;


-- Q4. Every suburb in the crime data matched a census area
-- Expected: 4,520 suburbs, 0 unmatched.
SELECT
    COUNT(DISTINCT sy.sal_code)                                      AS suburbs,
    COUNT(DISTINCT sy.sal_code) FILTER (WHERE c.sal_code IS NULL)    AS unmatched
FROM suburb_year sy
LEFT JOIN census c ON sy.sal_code = c.sal_code;


-- Q5. The yearly summary table adds up to the monthly suburb table (slow)
-- Expected: both totals 21,284,357.
SELECT
    (SELECT SUM(incident_count) FROM suburbs)     AS suburbs_total,
    (SELECT SUM(incident_count) FROM suburb_year) AS suburb_year_total;


-- Q6. SEIFA coverage
-- Expected: 222 census suburbs with no SEIFA row, 9 with no IRSD score.
-- All are small (none over 1,358 residents), so they fall under the population floors.
SELECT
    COUNT(*) FILTER (WHERE se.sal_code IS NULL)                              AS no_seifa_row,
    COUNT(*) FILTER (WHERE se.sal_code IS NOT NULL AND se.irsd_score IS NULL) AS no_irsd_score,
    MAX(c.total_population) FILTER (WHERE se.sal_code IS NULL
                                       OR se.irsd_score IS NULL)              AS largest_population_affected
FROM census c
LEFT JOIN seifa se ON c.sal_code = se.sal_code;


-- Q7. Impossible census values (ABS privacy adjustments)
-- The ABS adds small random changes to protect privacy, so in tiny areas a subgroup
-- can be larger than its total. Expected: only areas with 53 or fewer residents.
SELECT sal_name, total_population, pop_15_plus, completed_year12,
       total_labour_force, total_unemployed
FROM census
WHERE completed_year12 > pop_15_plus
   OR total_unemployed > total_labour_force
ORDER BY total_population DESC;
