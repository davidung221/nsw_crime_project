# Challenges and Fixes

This document records the real problems I ran into while building this project:
what went wrong, how I found the cause, and how I fixed it. They are grouped by
project stage, in roughly the order they happened.

For the full data pipeline, see [methodology.md](methodology.md). For the results,
see [findings.md](findings.md).

**Contents**
- [A. Data preparation](#a-data-preparation)
- [B. Building the database](#b-building-the-database)
- [C. Data validation](#c-data-validation)
- [D. Analysis](#d-analysis)
- [E. Power BI dashboard](#e-power-bi-dashboard)
- [Summary](#summary)

---

## A. Data preparation

### 1. Census data was spread across many ABS tables

**Problem:** the census variables I needed weren't in one file. They were spread
across many ABS DataPack tables, labelled with codes (e.g. "G01") rather than
descriptive names.

**Fix:** I used the ABS metadata files to identify the right table and column for
each variable, then combined them in Excel into one `census_data.csv` with clear
column names. Later, I added `pop_15_plus` the same way (see #15).

**Limitation:** this step was done by hand, so it isn't scripted. The source
tables are listed in [data_sources.md](data_sources.md).

### 2. Excel read the month headers as dates

**Problem:** in the NSW-wide file, the 378 month column headers ("Jan 1995" to
"Jun 2026") were read by pandas as date-time values instead of text, so the
month check couldn't recognise them.

**Fix:** the cleaning script converts any date headers back to "Jan 1995" text
before checking and reshaping them.

```python
if isinstance(col, datetime.datetime):
    new_names.append(col.strftime("%b %Y"))
```

### 3. The two BOCSAR files show "no subcategory" differently

**Problem:** 13 offence types (e.g. Arson) have no subcategory. The NSW-wide file
leaves the subcategory blank, but the suburb file repeats the category name
("Arson / Arson"). When matching suburb data to `offence_type`, these 13 showed as
unmatched.

**Fix:** `NULLIF` treats a subcategory that repeats the category name as blank
(NULL), so both files match the same offence type:

```sql
AND NULLIF(s.subcategory, s.offence_category) IS NOT DISTINCT FROM o.subcategory
```

---

## B. Building the database

### 4. Offence types without a subcategory broke the table

**Problem:** loading `offence_type` failed with a `NOT NULL` error on
`subcategory`.

**Cause:** offence types like Arson have no subcategory, so the value is genuinely
blank. The column was wrongly set to `NOT NULL`.

**Fix:** allowed `subcategory` to be NULL, since a missing subcategory is a real
feature of the data, not an error.

### 5. Rows silently disappeared during a join

**Problem:** after loading `nsw_incidents`, the row count was lower than the
staging table's. No error was shown.

**Cause:** the join used `s.subcategory = o.subcategory`. In SQL, `NULL = NULL`
isn't true, so every row with a blank subcategory failed to match and was
dropped.

**Fix:** used `IS NOT DISTINCT FROM`, which treats two NULLs as equal. Row counts
then matched exactly.

**Lesson:** a mismatch with no error is more dangerous than a crash. I compared
row counts after every load from then on.

### 6. Blank rows in the census file

**Problem:** the census staging table had 2 rows where `sal_code` was NULL.

**Cause:** both rows were completely empty, most likely blank lines at the end of
the CSV.

**Fix:** excluded them with `WHERE sal_code IS NOT NULL`, because `sal_code` is
the primary key of `census`.

### 7. Suburb names didn't match between BOCSAR and the census

**Problem:** many BOCSAR suburb names had no census match.

**Cause:** ABS names add text in brackets that BOCSAR leaves out, in two patterns:
- `Abbotsford (NSW)` vs `Abbotsford`
- `Alison (Central Coast - NSW)` vs `Alison (Central Coast)`

**Fix:** cleaned the census names with two `REGEXP_REPLACE` steps, matched each
BOCSAR suburb to its census code (`sal_code`) once, and stored that code on the
suburb data. Every later query joins on the code, not the name.

**Result:** all 4,520 BOCSAR suburbs matched a census area, with no duplicate
matches.

### 8. Slow queries with 100 million rows

**First build:** updating `sal_code` across 72.3 million rows ran for more than
15 minutes without finishing. The query was re-running the regex name cleaning
for every row it compared.

**Fix:** cleaned the 4,542 census names once into a small lookup table, indexed
it, and joined against that.

**Rebuild:** I improved this further by matching the 4,520 distinct suburb names
in a small lookup table first, then joining it during the insert. That avoided
updating 105.9 million rows afterwards.

**Still slow:** the 105.9 million-row insert took 41 minutes. Most of that time
was spent checking two foreign keys for every row. For a load this size,
temporarily removing the foreign keys and adding them back afterwards would be
faster.

### 9. The suburb table didn't follow the rest of the schema

**Problem:** the first version of the suburb table stored offence category and
subcategory as text on every row, while `nsw_incidents` used an `offence_id` link
to `offence_type`.

**Fix:** rebuilt the suburb table to use `offence_id`, the same as
`nsw_incidents`, so both fact tables share one offence lookup.

### 10. Missing SEIFA scores

**Problem:** converting the SEIFA scores to numbers failed for 9 suburbs, where
the value was `'-`.

**Cause:** the ABS doesn't publish an IRSD score for some very small areas.

**Fix:** loaded the scores as text first, then converted only values that are
numbers, leaving the rest blank:

```sql
CASE WHEN s.score_irsd ~ '^[0-9]+$' THEN s.score_irsd::INT END
```

A further 222 census suburbs have no SEIFA row at all. All are very small (none
has more than 1,358 residents), so none pass the analysis population floor.

---

## C. Data validation

### 11. Suburb data was cut off partway through the alphabet

This was the most important problem in the project.

**Problem:** a coverage check showed the suburb-level incident total was only
**66.5%** of the NSW total. The suburb data stopped at **"Padstow"**, so every
suburb from about P to Z was missing, including Sydney, Parramatta, Penrith and
Wollongong.

**How I found it:** I checked why so many census suburbs had no crime data, and
noticed every one started with P to Z. None of my ranking tables included a
suburb after N, even though places like Sydney should be near the top.

**Cause:** not confirmed. I considered two explanations:
- **Excel cut off the file when saving.** This is unlikely. The original wide
  file had about 193,000 rows (3,111 suburbs × 62 offence types), well under
  Excel's limit of 1,048,576 rows.
- **The original file was incomplete.** This is more likely. It was an older
  version named `SuburbDataQ1.csv`, which suggests it may only have been a
  partial release. The replacement file, updated 16 September 2026, was complete.

**Fix:**
- Downloaded the latest suburb data from BOCSAR (updated 16 September 2026) and
  reshaped it with a new cleaning script.
- Added checks to the script so this can't happen silently again:
  - first and last suburb names
  - first letters present (A–Z)
  - row counts before and after reshaping
  - incident totals before and after reshaping
  - rows written to the exported CSV
- Checked the database load against the script's counts.

**Result:**
| | Before | After |
|---|---|---|
| Suburbs | 3,111 | 4,520 |
| Last suburb | Padstow | Zetland |
| Suburb total as % of NSW total | 66.5% | 99.6% |

The remaining 0.4% (81,408 incidents) are incidents with no recorded suburb.

**Lesson:** a query that runs isn't the same as a correct result. I now check
coverage against a known total before analysing anything.

---

## D. Analysis

### 12. Per-capita rates for tiny suburbs were meaningless

**Problem:** the first per-capita ranking was led by places like Moore Park
(18 residents) and Bankstown Aerodrome (5 residents), with rates in the hundreds
of thousands or millions per 100,000.

**Cause:** dividing by a tiny population makes rates extremely unstable. One
incident in a suburb of 20 people moves its rate by 5,000 per 100,000.

**First fix:** a 5,000-resident population floor. On the truncated data, this
kept only 354 suburbs and 48.7% of the population, which was far too strict.

**Final fix:** I tested several floors and chose two, each for a different job:

| Floor | Used for | Population kept | One incident moves a rate by |
|---|---|---|---|
| 500 | Correlations, deciles, quartiles | 95.8% | 200 per 100K |
| 2,000 | Top-10 rate lists | 87.7% | 50 per 100K |

- **Correlations and deciles** average across hundreds of suburbs, so small-suburb
  noise evens out.
- **Rankings** pick out the extremes. At lower floors, the top-10 lists were led
  by commercial areas with few residents and, at 500, the "lowest-crime suburb"
  was a military training area.

**Robustness check:** the main unemployment result held at floors from 500 to
5,000 (r = 0.31–0.42, with about 3 times the crime rate in the highest-
unemployment quartile).

### 13. Small bugs found when reviewing the queries

Re-running the analysis on the full data turned up three mistakes in the
original queries:

- **Rates were rounding down to whole numbers.** `SUM(...) * 100000 / population`
  used whole-number division in places. Changed `100000` to `100000.0`.
- **"Last 5 years" was 6 years.** `BETWEEN 2020 AND 2025` includes six years.
  Changed it to 2021–2025.
- **Averages could be skewed by small suburbs.** Added a pooled rate (total
  incidents ÷ total residents) next to the average of suburb rates, as a check.
  Both gave about 4 times the crime rate in the most disadvantaged decile.

### 14. The 2021 rise came from COVID-19 rule enforcement

**Problem:** recorded crime rose 7.9% in 2021 and fell 9.2% in 2022, which didn't
fit the lockdown pattern seen in 2020.

**How I found the cause:**
1. Monthly totals showed a spike in July and August 2021, during Greater Sydney's
   Delta lockdown.
2. Comparing those months with the same months in 2019 by offence type showed
   that one category, "Other offences", jumped from 2,125 to 46,872.
3. This matches BOCSAR's report that NSW Police issued 36,597 public health order
   breaches in July and August 2021.

**Result:** without "Other offences", crime kept falling in 2021 (−2.6%). Most of
the 2022 "drop" was the end of the 2021 enforcement spike. The source data doesn't
say which category the breaches were recorded under, so findings.md describes the
link as likely rather than confirmed.

### 15. The Year 12 measure used the wrong denominator

**Problem:** the Year 12 completion rate showed almost no link to crime
(r = −0.06), while the ABS education and occupation index (IEO) showed a clearer
one (r = −0.16).

**Cause:** the Year 12 count covers people aged 15 and over, but I was dividing
it by the total population, including children. This understated the rate most in
suburbs with many young families.

**Fix:** added a population aged 15+ column and used it
as the denominator.

**Result:** the correlation doubled to −0.12, in line with IEO. Education on its
own still has only a weak link.

**Side finding:** in a few tiny areas, the Year 12 count was higher than the
population aged 15+. This comes from the small random adjustments the ABS makes
to protect privacy. All affected areas have 53 or fewer residents and are below
the population floors.

---

## E. Power BI dashboard

### 16. The first dashboard showed data but didn't tell a story

**Problem:** I shared the first version with three people for feedback. The main
criticisms were:
- No clear purpose: it felt like the reader had to work out the pattern themselves
- Three visuals all showing that theft was the most common offence
- A wrong "Avg Monthly Incidents" figure
- A map with no legend, and shading that didn't match the values
- No way to see the trend for a single offence type
- Slow performance

**Cause:** I had built an *exploratory* tool for browsing and filtering, which only another analyst would find useful. 
For a general audience, it was more meaningful to design a storytelling dashboard and describe key findings.

**Fix:** Rebuilt the dashboard as a storytelling tool to answer a core question, *"How has crime in NSW
changed, and where is it concentrated?"*, with one page for each part of the
answer: how it changed, where, and what it's linked to.

**Feedback I chose not to follow:** "Focus on Sydney only" would have hidden one
of the clearest findings, that violent crime rates are highest in regional NSW.

### 17. The report was slow with 105.9 million rows

**Problem:** loading monthly suburb data into Power BI made the report slow and
would have exceeded the publish-to-web size limit.

**Fix:** created `suburb_year`, a yearly summary of the suburb data, which has
about 12 times fewer rows. Monthly detail stays in the database, and NSW-wide
monthly analysis uses the much smaller `nsw_incidents` table.

---

## Summary

| # | Problem | Cause | Fix |
|---|---|---|---|
| 1 | Census data spread across many tables | ABS tables use coded labels | Mapped columns with ABS metadata and combined them in Excel |
| 2 | Month headers read as dates | Excel stores headers as dates | Converted them back to text in the cleaning script |
| 3 | 13 offence types didn't match | Files show "no subcategory" differently | `NULLIF` |
| 4 | `NOT NULL` error | Some offences genuinely have no subcategory | Allowed NULL |
| 5 | Rows silently dropped | `NULL = NULL` isn't true in SQL | `IS NOT DISTINCT FROM` |
| 6 | Blank census rows | Trailing blank lines in the CSV | Filtered out |
| 7 | Suburb names didn't match | ABS adds bracketed text | Regex cleaning, matched once by code |
| 8 | Queries ran for 15–41 minutes | Repeated regex work; per-row foreign key checks | Lookup tables; for future bulk loads, add foreign keys after loading |
| 9 | Suburb table inconsistent with schema | Category stored as text | Rebuilt with `offence_id` |
| 10 | SEIFA scores wouldn't convert | Missing values shown as `'-` | `CASE` to convert numbers only |
| 11 | Suburb data stopped at Padstow | Not confirmed; most likely an incomplete older file | Downloaded the latest file; added coverage checks |
| 12 | Extreme per-capita rates | Tiny populations | Tested floors: 500 and 2,000 |
| 13 | Rounding, date range and averaging errors | Query mistakes | Fixed during review; added pooled rate |
| 14 | 2021 rise didn't fit the pattern | COVID rule enforcement | Analysed with and without "Other offences" |
| 15 | Year 12 showed almost no link | Wrong denominator | Divided by population aged 15+ |
| 16 | Dashboard had no clear message | Built to explore, not explain | Rebuilt around one question |
| 17 | Slow report | 105.9M monthly rows | Yearly summary table |
