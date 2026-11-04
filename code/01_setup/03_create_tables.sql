-------------------------------
--- ### 03 CREATE TABLES ### ---
-------------------------------
-- Run after the two Python cleaning scripts.
-- Staging tables take the CSV files as they are (no constraints), so the load
-- never fails halfway. Final tables have primary keys, foreign keys and CHECK
-- constraints, and are filled from staging in 04_load_and_populate.sql.


-------------------------
--- 1. Staging tables ---
-------------------------

-- From 01_clean_nsw_data.py
CREATE TABLE staging_nsw_incidents (
    offence_category  TEXT,
    subcategory       TEXT,
    month             DATE,
    incident_count    INT
);

-- From 02_clean_suburb_data.py
CREATE TABLE staging_suburbs (
    suburb            TEXT,
    offence_category  TEXT,
    subcategory       TEXT,
    month             DATE,
    incident_count    INT
);

-- From the census CSV (combined from several ABS DataPack tables in Excel)
CREATE TABLE staging_census (
    sal_code                          TEXT,
    sal_name                          TEXT,
    total_population                  INT,
    completed_year12                  INT,
    total_labour_force                INT,
    total_unemployed                  INT,
    median_weekly_household_income    INT,
    served_in_adf                     INT,
    total_volunteers                  INT,
    pop_15_plus                       INT
);

-- From the ABS SEIFA 2021 SAL file. Loaded as text because missing scores
-- appear as '-', which can't be stored as a number.
CREATE TABLE staging_seifa (
    sal_code     TEXT,
    irsd_score   TEXT,
    irsd_decile  TEXT,
    ieo_score    TEXT,
    ieo_decile   TEXT
);


-----------------------
--- 2. Final tables ---
-----------------------

-- One row per offence type (62). Subcategory is NULL for offences that
-- have none, e.g. Arson.
CREATE TABLE offence_type (
    offence_id        SERIAL PRIMARY KEY,
    offence_category  VARCHAR(100) NOT NULL,
    subcategory       VARCHAR(150),
    UNIQUE (offence_category, subcategory)
);

-- NSW-wide monthly incidents (23,436 rows)
CREATE TABLE nsw_incidents (
    incident_id     BIGSERIAL PRIMARY KEY,
    offence_id      INT NOT NULL REFERENCES offence_type (offence_id),
    month           DATE NOT NULL,
    incident_count  INT NOT NULL CHECK (incident_count >= 0)
);

-- 2021 census, one row per suburb (SAL) (4,542 rows)
CREATE TABLE census (
    sal_code                          TEXT PRIMARY KEY,
    sal_name                          TEXT NOT NULL,
    total_population                  INT CHECK (total_population >= 0),
    pop_15_plus                       INT CHECK (pop_15_plus >= 0),
    completed_year12                  INT CHECK (completed_year12 >= 0),
    total_labour_force                INT CHECK (total_labour_force >= 0),
    total_unemployed                  INT CHECK (total_unemployed >= 0),
    median_weekly_household_income    INT CHECK (median_weekly_household_income >= 0),
    served_in_adf                     INT CHECK (served_in_adf >= 0),
    total_volunteers                  INT CHECK (total_volunteers >= 0)
);

-- SEIFA 2021 disadvantage indexes, one row per suburb (4,320 rows)
-- IRSD: lower score = more disadvantaged. Deciles rank all of Australia.
CREATE TABLE seifa (
    sal_code     TEXT PRIMARY KEY REFERENCES census (sal_code),
    irsd_score   INT,
    irsd_decile  INT CHECK (irsd_decile BETWEEN 1 AND 10),
    ieo_score    INT,
    ieo_decile   INT CHECK (ieo_decile BETWEEN 1 AND 10)
);

-- Monthly incidents by suburb (105,930,720 rows)
CREATE TABLE suburbs (
    incident_id     BIGSERIAL PRIMARY KEY,
    offence_id      INT NOT NULL REFERENCES offence_type (offence_id),
    suburb          TEXT NOT NULL,
    sal_code        TEXT REFERENCES census (sal_code),
    month           DATE NOT NULL,
    incident_count  INT NOT NULL CHECK (incident_count >= 0)
);

-- Yearly summary of suburbs (8,967,680 rows), about 12 times smaller.
-- Used for suburb analysis and the Power BI dashboard.
CREATE TABLE suburb_year (
    sal_code        TEXT REFERENCES census (sal_code),
    suburb          TEXT NOT NULL,
    offence_id      INT NOT NULL REFERENCES offence_type (offence_id),
    year            INT NOT NULL,
    incident_count  INT NOT NULL CHECK (incident_count >= 0),
    PRIMARY KEY (sal_code, offence_id, year)
);
