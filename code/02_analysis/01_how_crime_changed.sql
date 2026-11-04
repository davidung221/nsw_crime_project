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

-- EXTRA 1: COVID-19 check: yearly totals with and without "Other offences"
-- "Other offences" spiked during the 2020 and 2021 lockdowns, most likely
-- from public health order breaches. Removing it shows the underlying trend.
-- 2018 is included so 2019 has a previous year to compare against.
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM i.month) AS year,
        SUM(i.incident_count)                                                        AS total_all,
        SUM(i.incident_count) FILTER (WHERE ot.offence_category <> 'Other offences') AS total_excl_other
    FROM nsw_incidents i
    JOIN offence_type ot ON i.offence_id = ot.offence_id
    WHERE EXTRACT(YEAR FROM i.month) BETWEEN 2018 AND 2025
    GROUP BY EXTRACT(YEAR FROM i.month)
)
SELECT
    year,
    total_all,
    ROUND((total_all - LAG(total_all) OVER (ORDER BY year)) * 100.0
          / LAG(total_all) OVER (ORDER BY year), 1)               AS pct_change_all,
    total_excl_other,
    ROUND((total_excl_other - LAG(total_excl_other) OVER (ORDER BY year)) * 100.0
          / LAG(total_excl_other) OVER (ORDER BY year), 1)        AS pct_change_excl_other
FROM yearly
ORDER BY year;

-- EXTRA 2: Which offences drove the July - August 2021 spike?
-- Compares the same two months in 2019 (pre-COVID) and 2021 (Greater Sydney
-- Delta lockdown), sorted by the biggest increase.
SELECT
    ot.offence_category,
    ot.subcategory,
    SUM(i.incident_count) FILTER (WHERE EXTRACT(YEAR FROM i.month) = 2019) AS jul_aug_2019,
    SUM(i.incident_count) FILTER (WHERE EXTRACT(YEAR FROM i.month) = 2021) AS jul_aug_2021
FROM nsw_incidents i
JOIN offence_type ot ON i.offence_id = ot.offence_id
WHERE EXTRACT(MONTH FROM i.month) IN (7, 8)
  AND EXTRACT(YEAR FROM i.month) IN (2019, 2021)
GROUP BY ot.offence_category, ot.subcategory
ORDER BY (SUM(i.incident_count) FILTER (WHERE EXTRACT(YEAR FROM i.month) = 2021)
        - SUM(i.incident_count) FILTER (WHERE EXTRACT(YEAR FROM i.month) = 2019)) DESC
LIMIT 10;
