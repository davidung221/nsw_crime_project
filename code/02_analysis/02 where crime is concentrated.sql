-------------------------------------------------------
--- ### 02 WHERE IS CRIME CONCENTRATED? (SUBURBS) ###
-------------------------------------------------------
-- Source table: suburb_year (yearly totals by suburb and offence)
-- "Last 5 years" = 2021 - 2025 (five full years; 2026 is partial).
-- Per-capita rates use 2021 incidents, to match the 2021 census.
-- Population floor: suburbs with more than 500 residents
-- (keeps 95.8% of the NSW population; one incident moves a rate
-- by at most 200 per 100k).


-- Q4. Top 10 suburbs by total incidents, last 5 years (2021 - 2025)
-- Variant used in findings: remove the WHERE clause for all-time totals
-- (1995 - Jun 2026).
SELECT
    suburb,
    SUM(incident_count) AS total_incidents
FROM suburb_year
WHERE year BETWEEN 2021 AND 2025
GROUP BY suburb
ORDER BY total_incidents DESC
LIMIT 10;


-- Q5. Top 5 suburbs for abduction and kidnapping, last 5 years
SELECT
    s.suburb,
    SUM(s.incident_count) AS total_incidents
FROM suburb_year s
JOIN offence_type ot ON s.offence_id = ot.offence_id
WHERE ot.offence_category = 'Abduction and kidnapping'
  AND s.year BETWEEN 2021 AND 2025
GROUP BY s.suburb
ORDER BY total_incidents DESC
LIMIT 5;


-- Q6. Top 5 suburbs for murder, last 5 years
-- "Murder *" is BOCSAR's own label (the asterisk is a footnote marker).
SELECT
    s.suburb,
    SUM(s.incident_count) AS total_incidents
FROM suburb_year s
JOIN offence_type ot ON s.offence_id = ot.offence_id
WHERE ot.subcategory = 'Murder *'
  AND s.year BETWEEN 2021 AND 2025
GROUP BY s.suburb
ORDER BY total_incidents DESC
LIMIT 5;


-- Q7. Top 10 suburbs by incidents per 100k residents (2021, population floor of 2000)
-- Variant used in findings: ORDER BY ... ASC for the lowest 10.
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
WHERE c.total_population > 2000
ORDER BY incidents_per_100k DESC
LIMIT 10;


-- Q8. Top 10 suburbs by violent crime per 100k (assault + homicide, 2021, population floor of 2000)
WITH violent_totals AS (
    SELECT s.sal_code, SUM(s.incident_count) AS violent_incidents
    FROM suburb_year s
    JOIN offence_type ot ON s.offence_id = ot.offence_id
    WHERE s.year = 2021
      AND ot.offence_category IN ('Assault', 'Homicide')
    GROUP BY s.sal_code
)
SELECT
    c.sal_name,
    c.total_population,
    v.violent_incidents,
    ROUND(v.violent_incidents * 100000.0 / c.total_population, 0) AS violent_per_100k
FROM violent_totals v
JOIN census c ON v.sal_code = c.sal_code
WHERE c.total_population > 2000
ORDER BY violent_per_100k DESC
LIMIT 10;
