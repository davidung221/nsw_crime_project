--------------------------------------------------------
--- ### 03 WHAT IS CRIME LINKED TO? (2021, POP > 500) ###
--------------------------------------------------------
-- Sources: suburb_year, census, seifa
-- Correlation is not causation: these show which suburb characteristics
-- move together with crime rates, not what causes crime.
--
-- IRSD: lower score = MORE disadvantaged, so a negative correlation with
-- crime means crime rates are higher in more disadvantaged suburbs.
-- Decile 1 = most disadvantaged 10%, decile 10 = least disadvantaged.


-- Q9. Correlation between crime rate and each suburb characteristic
WITH suburb_totals AS (
    SELECT sal_code, SUM(incident_count) AS total_incidents
    FROM suburb_year
    WHERE year = 2021
    GROUP BY sal_code
),
suburb_profile AS (
    SELECT
        c.sal_name,
        t.total_incidents * 100000.0 / c.total_population                AS incidents_per_100k,
        c.median_weekly_household_income,
        c.total_unemployed * 100.0 / NULLIF(c.total_labour_force, 0)      AS unemployment_pct,
        c.completed_year12 * 100.0 / NULLIF(c.total_population, 0)        AS year12_pct,
        c.served_in_adf    * 100.0 / NULLIF(c.total_population, 0)        AS adf_pct,
        c.total_volunteers * 100.0 / NULLIF(c.total_population, 0)        AS volunteer_pct,
        se.irsd_score,
        se.ieo_score
    FROM suburb_totals t
    JOIN census c       ON t.sal_code = c.sal_code
    LEFT JOIN seifa se  ON t.sal_code = se.sal_code   -- LEFT JOIN keeps suburbs with no SEIFA score
    WHERE c.total_population > 500
)
SELECT
    COUNT(*)                                                                AS suburbs,
    ROUND(CORR(incidents_per_100k, irsd_score)::NUMERIC, 3)                 AS corr_irsd,
    ROUND(CORR(incidents_per_100k, unemployment_pct)::NUMERIC, 3)           AS corr_unemployment,
    ROUND(CORR(incidents_per_100k, median_weekly_household_income)::NUMERIC, 3) AS corr_income,
    ROUND(CORR(incidents_per_100k, year12_pct)::NUMERIC, 3)                 AS corr_year12,
    ROUND(CORR(incidents_per_100k, ieo_score)::NUMERIC, 3)                  AS corr_ieo,   -- check on the Year 12 result
    ROUND(CORR(incidents_per_100k, adf_pct)::NUMERIC, 3)                    AS corr_adf,
    ROUND(CORR(incidents_per_100k, volunteer_pct)::NUMERIC, 3)              AS corr_volunteer
FROM suburb_profile;


-- Q10. Crime rate by IRSD decile (main finding)
-- avg_rate    = average of each suburb's rate (every suburb counts equally)
-- pooled_rate = all incidents / all residents in the decile
-- (less affected by a few extreme suburbs)
WITH suburb_totals AS (
    SELECT sal_code, SUM(incident_count) AS total_incidents
    FROM suburb_year
    WHERE year = 2021
    GROUP BY sal_code
)
SELECT
    se.irsd_decile,
    COUNT(*)                                                         AS suburbs,
    ROUND(AVG(t.total_incidents * 100000.0 / c.total_population), 0) AS avg_rate_per_100k,
    ROUND(SUM(t.total_incidents) * 100000.0
          / SUM(c.total_population), 0)                              AS pooled_rate_per_100k
FROM suburb_totals t
JOIN census c ON t.sal_code = c.sal_code
JOIN seifa se ON t.sal_code = se.sal_code
WHERE c.total_population > 500
  AND se.irsd_decile IS NOT NULL
GROUP BY se.irsd_decile
ORDER BY se.irsd_decile;


-- Q11. Crime rate by unemployment quartile (supporting finding)
WITH suburb_totals AS (
    SELECT sal_code, SUM(incident_count) AS total_incidents
    FROM suburb_year
    WHERE year = 2021
    GROUP BY sal_code
),
rates AS (
    SELECT
        c.total_population,
        t.total_incidents,
        t.total_incidents * 100000.0 / c.total_population           AS incidents_per_100k,
        c.total_unemployed * 100.0 / NULLIF(c.total_labour_force, 0) AS unemployment_pct
    FROM suburb_totals t
    JOIN census c ON t.sal_code = c.sal_code
    WHERE c.total_population > 500
      AND c.total_labour_force > 0
),
quartiles AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY unemployment_pct) AS unemployment_quartile
    FROM rates
)
SELECT
    unemployment_quartile,
    COUNT(*)                                   AS suburbs,
    ROUND(AVG(unemployment_pct), 2)            AS avg_unemployment_pct,
    ROUND(AVG(incidents_per_100k), 0)          AS avg_rate_per_100k,
    ROUND(SUM(total_incidents) * 100000.0
          / SUM(total_population), 0)          AS pooled_rate_per_100k
FROM quartiles
GROUP BY unemployment_quartile
ORDER BY unemployment_quartile;
