-----------------------------------------------------------
--- ### 01 HOW HAS CRIME IN NSW CHANGED? (1995 - 2025) ###
-----------------------------------------------------------
-- Source table: nsw_incidents (monthly, NSW-wide)
-- 2026 is excluded from yearly comparisons: it only covers Jan - Jun.


-- Q1. Highest and lowest incident years
WITH yearly_totals AS (
    SELECT
        EXTRACT(YEAR FROM month) AS year,
        SUM(incident_count)     AS total_incidents
    FROM nsw_incidents
    WHERE month < DATE '2026-01-01'
    GROUP BY EXTRACT(YEAR FROM month)
)
(SELECT 'lowest'  AS rank, year, total_incidents FROM yearly_totals ORDER BY total_incidents ASC  LIMIT 1)
UNION ALL
(SELECT 'highest' AS rank, year, total_incidents FROM yearly_totals ORDER BY total_incidents DESC LIMIT 1);


-- Q2. Year-over-year % change in total incidents
WITH yearly_totals AS (
    SELECT
        EXTRACT(YEAR FROM month) AS year,
        SUM(incident_count)     AS total_incidents
    FROM nsw_incidents
    WHERE month < DATE '2026-01-01'
    GROUP BY EXTRACT(YEAR FROM month)
),
comparison AS (
    SELECT
        year,
        total_incidents,
        LAG(total_incidents) OVER (ORDER BY year) AS previous_year_total
    FROM yearly_totals
)
SELECT
    year,
    total_incidents,
    previous_year_total,
    ROUND((total_incidents - previous_year_total) * 100.0
          / NULLIF(previous_year_total, 0), 1) AS pct_change
FROM comparison
ORDER BY year;


-- Q3. Top 10 offence types, 2023 - 2025
-- Variant used in findings: change the years to 1995 AND 1997 to compare the top 10 from 30 years ago.
-- Note: The Offence Category 'Coercive Control' only became an offence in July 2024.
SELECT
    ot.offence_category,
    ot.subcategory,
    SUM(i.incident_count) AS total_incidents
FROM nsw_incidents i
JOIN offence_type ot ON i.offence_id = ot.offence_id
WHERE EXTRACT(YEAR FROM i.month) BETWEEN 2023 AND 2025
GROUP BY ot.offence_category, ot.subcategory
ORDER BY total_incidents DESC
LIMIT 10;
