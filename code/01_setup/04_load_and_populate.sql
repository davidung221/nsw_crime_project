---------------------------------------
--- ### 04 LOAD AND POPULATE ### ---
---------------------------------------
-- Run after 03_create_tables.sql, then run 03_checks/01_validation_checks.sql.
-- Change the file paths to wherever your CSV files are saved.
-- The column order in each COPY list must match the CSV's header row.


------------------------------------
--- 1. Load the CSVs into staging ---
------------------------------------

COPY staging_nsw_incidents (offence_category, subcategory, month, incident_count)
FROM 'C:/nsw_crime_project/data/clean/incidents_by_nsw_long.csv'
DELIMITER ',' CSV HEADER;

COPY staging_suburbs (suburb, offence_category, subcategory, month, incident_count)
FROM 'C:/nsw_crime_project/data/clean/incidents_by_suburb_long.csv'
DELIMITER ',' CSV HEADER;

COPY staging_census (
    sal_code, sal_name, total_population, completed_year12,
    total_labour_force, total_unemployed, median_weekly_household_income,
    served_in_adf, total_volunteers, pop_15_plus
)
FROM 'C:/nsw_crime_project/data/clean/Census_data.csv'
DELIMITER ',' CSV HEADER;

COPY staging_seifa (sal_code, irsd_score, irsd_decile, ieo_score, ieo_decile)
FROM 'C:/nsw_crime_project/data/clean/seifa_2021_sal.csv'
DELIMITER ',' CSV HEADER;


-------------------------
--- 2. Offence types ---
-------------------------

INSERT INTO offence_type (offence_category, subcategory)
SELECT DISTINCT offence_category, subcategory
FROM staging_nsw_incidents;


--------------------------
--- 3. NSW incidents ---
--------------------------
-- IS NOT DISTINCT FROM matches NULL to NULL. A plain "=" doesn't,
-- which silently dropped every offence with no subcategory.

INSERT INTO nsw_incidents (offence_id, month, incident_count)
SELECT
    o.offence_id,
    s.month,
    s.incident_count
FROM staging_nsw_incidents s
JOIN offence_type o
    ON  s.offence_category = o.offence_category
    AND s.subcategory IS NOT DISTINCT FROM o.subcategory;


-----------------
--- 4. Census ---
-----------------

INSERT INTO census (
    sal_code, sal_name, total_population, pop_15_plus, completed_year12,
    total_labour_force, total_unemployed, median_weekly_household_income,
    served_in_adf, total_volunteers
)
SELECT
    sal_code, sal_name, total_population, pop_15_plus, completed_year12,
    total_labour_force, total_unemployed, median_weekly_household_income,
    served_in_adf, total_volunteers
FROM staging_census
WHERE sal_code IS NOT NULL;      -- skips blank rows at the end of the file


----------------
--- 5. SEIFA ---
----------------
-- Missing scores appear as '-', so only text made entirely of digits is
-- converted to a number. Everything else becomes NULL.

INSERT INTO seifa (sal_code, irsd_score, irsd_decile, ieo_score, ieo_decile)
SELECT
    sal_code,
    CASE WHEN irsd_score  ~ '^[0-9]+$' THEN irsd_score::INT  END,
    CASE WHEN irsd_decile ~ '^[0-9]+$' THEN irsd_decile::INT END,
    CASE WHEN ieo_score   ~ '^[0-9]+$' THEN ieo_score::INT   END,
    CASE WHEN ieo_decile  ~ '^[0-9]+$' THEN ieo_decile::INT  END
FROM staging_seifa
WHERE sal_code IN (SELECT sal_code FROM census);   -- NSW suburbs only


---------------------------------------------
--- 6. Match BOCSAR suburbs to census areas ---
---------------------------------------------
-- The ABS adds bracketed text to some names, e.g. "Abbotsford (NSW)" or
-- "Bald Hills (Bega Valley - NSW)". Cleaning both sides and matching each
-- distinct name once (about 4,500 names) is far faster than cleaning
-- 105.9 million rows during the insert.

CREATE TABLE suburb_lookup AS
SELECT
    s.suburb,
    c.sal_code
FROM (SELECT DISTINCT suburb FROM staging_suburbs) s
JOIN census c
    ON TRIM(UPPER(s.suburb)) = TRIM(UPPER(
           REGEXP_REPLACE(
               REGEXP_REPLACE(c.sal_name, '\s*-\s*NSW\)$', ')'),
               '\s*\(NSW\)$', ''
           )
       ));

-- Check before continuing: should return 0 rows
SELECT DISTINCT suburb
FROM staging_suburbs
WHERE suburb NOT IN (SELECT suburb FROM suburb_lookup);


--------------------------------------
--- 7. Suburb incidents (slow step) ---
--------------------------------------
-- NULLIF handles the suburb file repeating the category as the subcategory
-- (e.g. "Arson / Arson") where the NSW file leaves it blank.
-- Took about 41 minutes, mostly foreign key checks on every row.

INSERT INTO suburbs (offence_id, suburb, sal_code, month, incident_count)
SELECT
    o.offence_id,
    s.suburb,
    l.sal_code,
    s.month,
    s.incident_count
FROM staging_suburbs s
JOIN suburb_lookup l
    ON s.suburb = l.suburb
JOIN offence_type o
    ON  s.offence_category = o.offence_category
    AND NULLIF(s.subcategory, s.offence_category) IS NOT DISTINCT FROM o.subcategory;


------------------------------
--- 8. Yearly summary table ---
------------------------------

INSERT INTO suburb_year (sal_code, suburb, offence_id, year, incident_count)
SELECT
    sal_code,
    suburb,
    offence_id,
    EXTRACT(YEAR FROM month)::INT AS year,
    SUM(incident_count)
FROM suburbs
GROUP BY sal_code, suburb, offence_id, EXTRACT(YEAR FROM month);


-------------------
--- 9. Clean up ---
-------------------

DROP TABLE suburb_lookup;
DROP TABLE staging_nsw_incidents;
DROP TABLE staging_suburbs;
DROP TABLE staging_census;
DROP TABLE staging_seifa;
