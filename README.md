# NSW Crime Analysis

An end-to-end SQL data analysis project exploring 30 years of criminal incident
data across NSW, using PostgreSQL. The project covers database design, data
cleaning, normalisation, and analysis (including a socioeconomic correlation
study built by joining incident data to 2021 census data at the suburb level).

**Status:** SQL analysis complete. Power BI dashboard in progress.

---

## Project overview

Source data: [NSW Bureau of Crime Statistics and Research (BOCSAR)](https://bocsar.nsw.gov.au/statistics-dashboards/open-datasets/criminal-offences-data.html)
and the [2021 ABS Census (SAL geography)](https://www.abs.gov.au/census/find-census-data/datapacks?release=2021&product=GCP&geography=SAL&header=S).

This project analyses:
- NSW-wide criminal incident trends from 1995 to 2025
- How the composition of crime has changed over 30 years
- Suburb-level incident rankings, by volume and per capita
- Whether socioeconomic factors (income, unemployment, education) correlate
  with incident rates at the suburb level

Full methodology, challenges, and findings are documented in [`docs/`](docs/).

---

## Schema

Four tables: two lookup/reference tables (`offence_type`, `census`) and two
fact tables (`incidents`, `suburbs`), linked as follows:

- `offence_type` classifies both `incidents` and `suburbs`, via `offence_id`
- `census` links to `suburbs`, via `sal_code`

![NSW crime database schema](images/table_schema.png)

| Table | Grain | Key columns |
|---|---|---|
| `offence_type` | One row per offence category/subcategory | `offence_id` (PK) |
| `incidents` | One row per offence type, per month (NSW-wide) | `offence_id` (FK) |
| `suburbs` | One row per offence type, per month, per suburb | `offence_id` (FK), `sal_code` (FK) |
| `census` | One row per suburb (SAL) | `sal_code` (PK) |

`CREATE TABLE` statements are in [`sql/01_setup/`](sql/01_setup/).

---

## Key findings

**NSW-wide trends:** total recorded incidents rose from 1995, peaked in 2001,
and have declined fairly steadily since. 2020 saw the largest single-year
drop, consistent with COVID-19 lockdown restrictions.

**Crime composition has shifted substantially over 30 years.** In 1995-1997,
7 of the top 10 offence types were theft-related. By 2023-2025, regulatory and
justice-procedure offences (transport regulatory offences and breaching bail
conditions)lead the list instead, alongside a continued strong presence of
theft and the emergence of domestic violence assault as a top-10 category.

**Per-capita analysis** (2021, suburbs with population > 5,000) found the
highest incident rates in Haymarket, Mount Druitt, Campbelltown, Liverpool,
and Moree, and the lowest in low-density residential suburbs including
Cherrybrook, Hornsby Heights, and Glenhaven.

**Unemployment rate showed the strongest socioeconomic correlation** with
incidents-per-capita (r = 0.379), followed by median household income
(r = -0.329). Suburbs in the highest unemployment quartile show a per-capita
incident rate roughly **three times** that of the lowest quartile.

Full findings, including all result tables and their interpretation, are in
[`docs/findings.md`](docs/findings.md).

---

## Tech stack

- **PostgreSQL** — schema design, data cleaning, analysis
- **Python (pandas)** — reshaping tables, data cleaning
- **Excel** — manual assembly of the census dataset from multiple ABS source tables
- **Power BI** — dashboard (in progress)

---

## Notable technical points

Things worth highlighting from the build process — full detail in
[`docs/challenges_and_fixes.md`](docs/challenges_and_fixes.md):

- **Handled a 72.3 million row performance bottleneck.** Matching suburb names
  between the incident data and census data required text normalisation using regex
  (stripping ABS formatting like `"(NSW)"`) that, computed inline, didn't
  complete after 15+ minutes. Rebuilt as a pre-computed, indexed lookup table,
  which resolved the issue.
- **Diagnosed a silent data-loss bug** caused by `NULL = NULL` evaluating to
  false in a SQL join, using `IS NOT DISTINCT FROM` to fix it.
- **Normalised the schema consistently**, using lookup tables and foreign keys
  (`offence_type`, `census`) rather than repeating category text across
  millions of rows.

---

## Limitations

The constraints of this project are detailed in 
[`docs/findings.md`](docs/findings.md#limitations). Limitations include the use of a
single census year (2021), variables influenced by various unaccounted confounders, and 
incidents-per-capita analysis excluding smaller suburb populations.
