# NSW Crime Analysis

**How has crime in NSW changed over 30 years, and where is it concentrated?**

An end-to-end SQL analysis of 30 years of police-recorded criminal incidents across
NSW, built in PostgreSQL. The project covers database design, data cleaning,
normalisation and analysis, including a socioeconomic correlation study that joins
incident data to 2021 Census data at the suburb level.

**Power BI dashboard (in progress):** the overview page is complete, and the three
detail pages are being built.

---

## Project overview

**Data sources**
- [NSW Bureau of Crime Statistics and Research (BOCSAR)](https://bocsar.nsw.gov.au/statistics-dashboards/open-datasets/criminal-offences-data.html):
  monthly recorded incidents by offence type and suburb, 1995–2025
- [2021 ABS Census (SAL geography)](https://www.abs.gov.au/census/find-census-data/datapacks?release=2021&product=GCP&geography=SAL&header=S):
  population and socioeconomic indicators by suburb

**Questions this project answers**
- How have total recorded incidents in NSW changed between 1995 and 2025?
- How has the mix of offence types changed over 30 years?
- Which suburbs have the most crime, by volume and per resident?
- Do socioeconomic factors (unemployment, income, education, volunteering and ADF
  service) relate to suburb crime rates?

Full methodology, challenges and findings are documented in [`docs/`](docs/).

---

## Schema

Four tables: two reference tables (`offence_type`, `census`) and two fact tables
of incident counts (`incidents`, `suburbs`).

| Table | Type | Grain | Keys |
|---|---|---|---|
| `offence_type` | Reference | One row per offence category/subcategory | `offence_id` (PK) |
| `census` | Reference | One row per suburb (SAL) | `sal_code` (PK) |
| `incidents` | Fact | One row per offence type, per month (NSW-wide) | `offence_id` (FK) |
| `suburbs` | Fact | One row per offence type, per month, per suburb | `offence_id` (FK), `sal_code` (FK) |

**Relationships**
- `offence_type` → `incidents` and `suburbs`, via `offence_id`
- `census` → `suburbs`, via `sal_code`

`CREATE TABLE` statements are in [`sql/01_setup/`](sql/01_setup/).

---

## Key findings

**Crime peaked in 2001 and has generally declined since.** Recorded incidents rose
from 528,888 in 1995 to a peak of 795,851 in 2001 (about 2,180 a day), then generally
fell, with some fluctuation. 2020 had the largest single-year drop in the dataset,
consistent with COVID-19 lockdowns.

**Theft no longer dominates.** In 1995–1997, 8 of the 10 most common offence types
were theft. By 2023–2025, only 3 were. Transport regulatory offences and breaches of
bail conditions now top the list, and domestic violence assault and breaches of AVOs
have entered the top 10. Part of this shift likely reflects changes in policing and
recording practices, not just changes in behaviour.

**Where crime concentrates depends on how you measure it.**
- **By volume (2020–2025):** Liverpool, Blacktown and Mount Druitt lead.
- **Per resident (2021, suburbs with 5,000+ residents):** Haymarket, Mount Druitt and
  Campbelltown lead. Haymarket's rate reflects its large visitor and worker
  population, not just its residents.
- **Violent crime per resident:** regional towns lead, led by Moree, Bathurst and Nowra.

**Crime rates rise with unemployment.** Unemployment rate had the strongest correlation
with suburb crime rates (r = 0.38), followed by median household income (r = −0.33).
Suburbs in the highest-unemployment quartile have roughly **three times** the crime
rate of the lowest. These are associations, not causes: unemployment and income
overlap, and population density and visitor numbers weren't controlled for.

Full findings, including all result tables and their interpretation, are in
[`docs/findings.md`](docs/findings.md).

---

## Tech stack

- **PostgreSQL:** schema design, data cleaning, analysis
- **Python (pandas):** reshaping tables, data cleaning
- **Excel:** manual assembly of the census dataset from multiple ABS source tables
- **Power BI:** dashboard (in progress)

---

## Notable technical points

Things worth highlighting from the build process — full detail in
[`docs/challenges_and_fixes.md`](docs/challenges_and_fixes.md):

- **Fixed a performance bottleneck across 72.3 million rows.** Matching suburb names
  between the incident and census data needed regex-based text normalisation (for
  example, stripping ABS suffixes like `"(NSW)"`). Run inline in the join, the query
  still hadn't finished after 15+ minutes. Precomputing the normalised names into an
  indexed lookup table resolved it.
- **Found and fixed a silent data-loss bug.** In SQL, `NULL = NULL` evaluates to `NULL`
  rather than true, so rows with `NULL` join keys were silently dropped from a join.
  Changing the join condition to `IS NOT DISTINCT FROM` fixed it.
- **Normalised the schema** with lookup tables and foreign keys, instead of repeating
  category and suburb text across millions of rows.

---

## Limitations

The constraints of this project are detailed in 
[`docs/findings.md`](docs/findings.md#limitations). Limitations include the use of a
single census year (2021), variables influenced by various unaccounted confounders, and 
incidents-per-capita analysis excluding smaller suburb populations.
