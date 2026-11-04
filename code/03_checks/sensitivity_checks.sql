-------------------------------------------------
--- 04 SENSITIVITY CHECKS (POPULATION FLOORS) ---
-------------------------------------------------
-- Sources: suburb_year, census
-- Rates for very small suburbs are unstable, so the analysis uses population floors:
--   500 residents   for correlations, deciles and quartiles
--   2,000 residents for top-10 rate lists
-- These checks show how much each floor removes, and that the main result
-- doesn't depend on the floor chosen.


-- Q1. How much of NSW each floor keeps
-- Expected: 500 keeps 95.8% of the population, 2,000 keeps 87.7%.
WITH floors (pop_floor) AS (
    VALUES (0), (500), (1000), (2000), (5000)
)
SELECT
    f.pop_floor,
    COUNT(*) FILTER (WHERE c.total_population > f.pop_floor)               AS suburbs_kept,
    ROUND(SUM(c.total_population) FILTER (WHERE c.total_population > f.pop_floor) * 100.0
          / SUM(c.total_population), 1)                                     AS pct_population_kept
FROM census c
CROSS JOIN floors f
GROUP BY f.pop_floor
ORDER BY f.pop_floor;


-- Q2. Unemployment result at each floor
-- Expected (findings.md):
--   500 -> 1,573 suburbs, r 0.31, 2.85x | 1,000 -> 1,264, 0.34, 2.97x
--   2,000 -> 962, 0.42, 3.47x           | 5,000 -> 513, 0.38, 3.08x
-- ratio = average rate in the highest-unemployment quartile / lowest quartile
WITH floors (pop_floor) AS (
    VALUES (500), (1000), (2000), (5000)
),
suburb_totals AS (
    SELECT sal_code, SUM(incident_count) AS total_incidents
    FROM suburb_year
    WHERE year = 2021
    GROUP BY sal_code
),
rates AS (
    SELECT
        f.pop_floor,
        t.total_incidents * 100000.0 / c.total_population           AS incidents_per_100k,
        c.total_unemployed * 100.0 / NULLIF(c.total_labour_force, 0) AS unemployment_pct
    FROM suburb_totals t
    JOIN census c ON t.sal_code = c.sal_code
    CROSS JOIN floors f
    WHERE c.total_population > f.pop_floor
      AND c.total_labour_force > 0
),
quartiles AS (
    SELECT *,
           NTILE(4) OVER (PARTITION BY pop_floor ORDER BY unemployment_pct) AS unemployment_quartile
    FROM rates
)
SELECT
    pop_floor,
    COUNT(*)                                                          AS suburbs,
    ROUND(CORR(incidents_per_100k, unemployment_pct)::NUMERIC, 2)     AS corr_unemployment,
    ROUND((AVG(incidents_per_100k) FILTER (WHERE unemployment_quartile = 4)
         / AVG(incidents_per_100k) FILTER (WHERE unemployment_quartile = 1))::NUMERIC, 2) AS q4_vs_q1_ratio
FROM quartiles
GROUP BY pop_floor
ORDER BY pop_floor;


-- Q3. Top 10 rate per 100K at a lower floor
-- Used to choose the 2,000 floor for top-10 lists: at 500 or 1,000, the top of the
-- list is led by commercial areas with few residents (e.g. Maitland CBD, Sydenham)
-- and non-residential land (e.g. Singleton Military Area at the bottom).
-- Change the floor below to 500, 1000 or 2000 to compare.
WITH suburb_totals AS (
    SELECT sal_code, SUM(incident_count) AS total_incidents
    FROM suburb_year
    WHERE year = 2021
    GROUP BY sal_code
)
SELECT
    c.sal_name,
    c.total_population,
    t.total_incidents,
    ROUND(t.total_incidents * 100000.0 / c.total_population, 0) AS incidents_per_100k
FROM suburb_totals t
JOIN census c ON t.sal_code = c.sal_code
WHERE c.total_population > 500        -- change to 1000 or 2000
ORDER BY incidents_per_100k DESC
LIMIT 10;
