# Findings

**Question:** How has crime in NSW changed, and where is it concentrated?

The analysis is split into three parts, which match the SQL files in
`sql/02_analysis/` and the pages of the dashboard:

1. [How has crime changed?](#1-how-has-crime-changed)
2. [Where is crime concentrated?](#2-where-is-crime-concentrated)
3. [What is crime linked to?](#3-what-is-crime-linked-to)

These results use the full suburb dataset (4,520 suburbs), loaded after the
data truncation issue described in [challenges_and_fixes.md](challenges_and_fixes.md).

### Conventions used throughout

- **Recorded crime:** all figures are criminal incidents recorded by NSW Police
  (BOCSAR), not all crime that occurred.
- **2026 is excluded** from yearly comparisons, because the data only covers
  January to June 2026.
- **Rates are per 100,000 residents**, using 2021 incidents and 2021 census
  populations so the two line up in time.
- **Population floors:** rates for very small suburbs are unstable, because one
  incident can move them a lot. Two floors are used:
  - **500 residents** for correlations, deciles and quartiles (keeps 95.8% of
    the NSW population). These average across hundreds of suburbs, so small-suburb
    noise evens out.
  - **2,000 residents** for top-10 rate lists (keeps 87.7% of the population).
    Rankings pick out the extremes, which is where small-population noise sits.

---

## 1. How has crime changed?

*SQL: `01_how_crime_changed.sql`*

### Recorded crime peaked in 2001 and has fallen about 21% since

| | Year | Recorded incidents |
|---|---|---|
| Start of data | 1995 | 529,206 |
| **Peak** | **2001** | **796,444** |
| Most recent full year | 2025 | 625,679 |

- Recorded incidents rose about 50% from 1995 to the 2001 peak, then fell
  steadily through the mid-2000s and stayed fairly flat from 2005 to 2019.
- 2025 is **21% below the 2001 peak.**
- These are counts, not rates. NSW's population grew over this period, so the
  fall per resident is likely larger than the fall in counts.

### COVID-19: a real drop in 2020, and a rule-enforcement spike in 2021

At first glance, 2020–2022 looks like a drop, a rebound, then another drop.
Removing the "Other offences" category shows a different picture:

| Year | All offences | Change | Excluding "Other offences" | Change |
|---|---|---|---|---|
| 2019 | 714,183 | +3.2% | 699,514 | +3.3% |
| 2020 | 636,100 | **−10.9%** | 608,555 | **−13.0%** |
| 2021 | 686,187 | +7.9% | 592,726 | −2.6% |
| 2022 | 622,909 | −9.2% | 602,091 | +1.6% |
| 2023 | 649,948 | +4.3% | 636,416 | +5.7% |

- **2020's drop was real.** Recorded crime fell 13% across the usual offence
  types, in line with the first COVID-19 lockdowns.
- **2021's rise came from one category.** "Other offences" jumped from 2,125 in
  July–August 2019 to 46,872 in July–August 2021, during Greater Sydney's Delta
  lockdown. This is consistent with enforcement of COVID-19 public health
  orders: BOCSAR reported that NSW Police issued 36,597 public health order
  breaches in those two months ([BOCSAR, 2021](https://bocsar.nsw.gov.au/media/2021/mr-covid-breaches-bb157.html)).
- **Without that category, crime kept falling in 2021 (−2.6%)**, then recovered
  slowly in 2022–2023. The 2022 "drop" in the all-offences figures is mostly
  the end of the 2021 enforcement spike.
- **Recorded crime hasn't returned to pre-COVID levels.** Excluding "Other
  offences", 2025 is 12% below 2019.

*Note: the source data doesn't say which category public health order breaches
were recorded under. The match in timing and size makes "Other offences" the
likely category, but this is an inference, not something the data confirms.*

### Property crime used to dominate; now regulatory and justice offences lead

Top 10 offence types by recorded incidents:

| Rank | Past (1995–1997) | Present (2023–2025) |
|---|---|---|
| 1 | Malicious damage to property | Transport regulatory offences |
| 2 | Theft — Break and enter dwelling | Against justice procedures — Breach bail conditions |
| 3 | Theft — Steal from motor vehicle | Intimidation, stalking and harassment |
| 4 | Theft — Other theft | Malicious damage to property |
| 5 | Theft — Motor vehicle theft | Theft — Fraud |
| 6 | Theft — Break and enter non-dwelling | Assault — Domestic violence related |
| 7 | Assault — Non-domestic violence related | Assault — Non-domestic violence related |
| 8 | Theft — Steal from dwelling | Theft — Steal from retail store |
| 9 | Theft — Steal from retail store | Theft — Steal from motor vehicle |
| 10 | Theft — Fraud | Against justice procedures — Breach AVO |

- **In 1995–1997, 8 of the top 10 were theft offences.** By 2023–2025, only 3 were.
- Break and enter of homes was the second most common offence in 1995–1997
  (214,267 incidents). It is no longer in the top 10.
- **Fraud doubled** (65,033 → 129,202 incidents) and rose from #10 to #5.
- **New entries:** transport regulatory offences, breaching bail, intimidation and
  stalking, domestic violence assault, and breaching an Apprehended Violence Order.
- Non-domestic violence assault is the only offence type at the same rank
  (#7) in both periods.

**Caution:** some of this shift reflects changes in policing and law, not just
behaviour. Offences such as breaching bail and transport regulatory offences are
mostly detected through police activity, so their counts reflect enforcement as
well as offending. Recording practices for domestic violence have also changed
over 30 years.

---

## 2. Where is crime concentrated?

*SQL: `02_where_crime_is_concentrated.sql`*

### By volume: Liverpool leads recently, Sydney CBD leads all-time

**Total incidents, last 5 years (2021–2025):**

| Rank | Suburb | Incidents |
|---|---|---|
| 1 | Liverpool | 61,268 |
| 2 | Blacktown | 57,166 |
| 3 | Parramatta | 50,878 |
| 4 | Mount Druitt | 47,724 |
| 5 | Sydney | 46,351 |
| 6 | Dubbo | 39,921 |
| 7 | Penrith | 37,877 |
| 8 | Campbelltown | 37,404 |
| 9 | Haymarket | 36,018 |
| 10 | Wollongong | 29,269 |

**Total incidents, all time (1995 – June 2026):**

| Rank | Suburb | Incidents |
|---|---|---|
| 1 | Sydney | 419,138 |
| 2 | Blacktown | 297,458 |
| 3 | Liverpool | 272,042 |
| 4 | Parramatta | 256,016 |
| 5 | Dubbo | 207,613 |
| 6 | Campbelltown | 198,609 |
| 7 | Haymarket | 197,561 |
| 8 | Penrith | 192,496 |
| 9 | Wollongong | 187,911 |
| 10 | Bankstown | 172,791 |

- The list is mostly large centres in Greater Sydney, plus Dubbo and Wollongong.
- Sydney CBD leads all-time but is 5th over the last 5 years. Liverpool,
  Blacktown, Parramatta and Mount Druitt now record more.
- **Volume mostly reflects size.** Places with more residents and visitors record
  more incidents, so these lists show where incidents happen, not where risk is
  highest. Per-resident rates are below.

### Serious offences: small counts, read with care

**Abduction and kidnapping, 2021–2025:**

| Rank | Suburb | Incidents |
|---|---|---|
| 1 | Dubbo | 22 |
| 2 | Auburn | 15 |
| 2 | Bankstown | 15 |
| 4 | Blacktown | 13 |
| 4 | Greenacre | 13 |

**Murder, 2021–2025:**

| Rank | Suburb | Incidents |
|---|---|---|
| 1 | Bondi Beach | 15 |
| 2 | Bondi Junction | 7 |
| 2 | Coffs Harbour | 7 |
| 4 | Greenacre | 4 |
| 4 | Guildford | 4 |

- At these low counts, one or two events can change the order. Treat these lists
  as indicative only.
- "Murder \*" is BOCSAR's own label. The asterisk is a footnote marker in the
  source data.

### By rate: CBDs, outer western Sydney and regional centres

**Highest incidents per 100,000 residents (2021, suburbs with more than 2,000 residents):**

| Rank | Suburb | Residents | Incidents | Per 100K |
|---|---|---|---|---|
| 1 | Haymarket | 8,305 | 9,757 | 117,483 |
| 2 | Gosford | 4,873 | 4,996 | 102,524 |
| 3 | North St Marys | 4,123 | 3,926 | 95,222 |
| 4 | Sydney | 16,667 | 11,244 | 67,463 |
| 5 | Mount Druitt | 16,986 | 9,818 | 57,801 |
| 6 | Lismore | 3,656 | 1,809 | 49,480 |
| 7 | Campbelltown | 16,577 | 8,143 | 49,122 |
| 8 | Potts Point | 7,183 | 3,316 | 46,165 |
| 9 | Wyong | 4,530 | 1,976 | 43,620 |
| 10 | Parramatta | 30,211 | 11,944 | 39,535 |

**Lowest incidents per 100,000 residents (2021, suburbs with more than 2,000 residents):**

| Rank | Suburb | Residents | Incidents | Per 100K |
|---|---|---|---|---|
| 1 | Cordeaux Heights | 4,460 | 39 | 874 |
| 2 | Liberty Grove | 2,055 | 18 | 876 |
| 3 | Camden Park | 2,233 | 21 | 940 |
| 4 | Davidson | 2,725 | 28 | 1,028 |
| 5 | St Ives Chase | 3,283 | 37 | 1,127 |
| 6 | Tura Beach | 3,405 | 41 | 1,204 |
| 7 | Cherrybrook | 19,082 | 239 | 1,252 |
| 8 | Camden South | 4,595 | 58 | 1,262 |
| 9 | North Epping | 4,657 | 59 | 1,267 |
| 10 | East Ryde | 2,522 | 33 | 1,308 |

- **The highest rates fall into three groups:**
  - **CBD and commercial centres** (Haymarket, Sydney, Gosford, Potts Point,
    Parramatta). These have many visitors but few residents, which raises a rate
    calculated per resident.
  - **Outer western and south-western Sydney** (North St Marys, Mount Druitt,
    Campbelltown).
  - **Regional centres** (Lismore, Wyong).
- **The lowest rates are mostly low-density residential suburbs**, many in
  northern and north-western Greater Sydney (Cherrybrook, St Ives Chase,
  North Epping, Davidson).
- The highest-rate suburb (Haymarket) has a rate about **130 times** that of the
  lowest (Cordeaux Heights).

### Violent crime rates are highest in regional NSW

**Highest assault and homicide incidents per 100,000 residents (2021, suburbs with more than 2,000 residents):**

| Rank | Suburb | Residents | Violent incidents | Per 100K |
|---|---|---|---|---|
| 1 | Lismore | 3,656 | 203 | 5,553 |
| 2 | Coonamble | 2,666 | 134 | 5,026 |
| 3 | Sydney | 16,667 | 732 | 4,392 |
| 4 | Moree | 8,962 | 378 | 4,218 |
| 5 | Bathurst | 7,001 | 260 | 3,714 |
| 6 | Albury | 4,955 | 182 | 3,673 |
| 7 | West Tamworth | 5,471 | 198 | 3,619 |
| 8 | Wellington | 4,096 | 147 | 3,589 |
| 9 | Ashmont | 3,747 | 133 | 3,550 |
| 10 | South Kempsey | 2,604 | 90 | 3,456 |

- **9 of the top 10 are regional towns.** Sydney CBD is the only Greater Sydney
  suburb on the list.
- This differs from the all-offences list, where Greater Sydney dominates. It is
  one reason the analysis keeps all of NSW rather than focusing on Sydney only.
- **Read with care.** Recorded violent crime reflects policing and reporting
  levels as well as offending, and these are smaller communities. These figures
  describe where recorded rates are highest; they are not a measure of how safe a
  town is. Section 3 looks at how rates relate to disadvantage.

### Why a 2,000 floor for these lists

The lists were also run at floors of 500 and 1,000. At those levels, the top
of the lists was led by places where a rate per resident is misleading:

- **Commercial and industrial areas with few residents,** such as Maitland CBD,
  Sydenham, Broadmeadow and Wickham. Their incidents involve shoppers and workers,
  but their rates divide by a small number of residents.
- **Non-residential land:** at a 500 floor, the lowest-rate "suburb" was the
  Singleton Military Area.
- **Very small places,** whose rates change more from year to year, so a single
  year's ranking is less reliable.

A 2,000 floor removes most of these. **The trade-off:** it also drops some small
towns with genuinely high rates, such as Bourke and Walgett. They are still
included in the correlation and decile analysis in Section 3, which uses a
500 floor.

---

## 3. What is crime linked to?

*SQL: `03_links_to_disadvantage.sql`*

All results in this section use 2021 data and suburbs with more than 500 residents
(1,573 suburbs).

**IRSD** is the ABS's Index of Relative Socio-economic Disadvantage, from SEIFA
2021. A lower score means a more disadvantaged area. Decile 1 is the most
disadvantaged 10% of areas; decile 10 is the least disadvantaged.

### The most disadvantaged suburbs have about 4 times the crime rate of the least disadvantaged

| IRSD decile | Suburbs | Pooled rate per 100K | Average rate per 100K |
|---|---|---|---|
| **1 (most disadvantaged)** | 184 | **13,830** | 14,787 |
| 2 | 190 | 14,407 | 11,518 |
| 3 | 124 | 11,124 | 8,942 |
| 4 | 152 | 9,371 | 8,372 |
| 5 | 127 | 8,492 | 6,262 |
| 6 | 101 | 6,296 | 6,597 |
| 7 | 132 | 7,022 | 6,199 |
| 8 | 114 | 5,217 | 4,921 |
| 9 | 141 | 5,405 | 4,435 |
| **10 (least disadvantaged)** | 306 | **3,450** | 3,644 |

- **Decile 1 vs decile 10: 4.0× (pooled rate), 4.1× (average rate).**
- The rate **generally falls** as disadvantage decreases. It doesn't fall at every
  single step (for example, decile 2's pooled rate is slightly above decile 1's).
- **Two ways of calculating the rate:**
  - **Pooled rate:** all incidents in the decile ÷ all residents in the decile.
    Every resident counts equally. This is the main figure.
  - **Average rate:** the average of each suburb's own rate. Every suburb counts
    equally, so a few small, high-rate suburbs can pull it up.
  - Both give about 4×, so the finding doesn't depend on the method.

### Disadvantage overall shows a stronger link than any single factor

Correlation between each suburb's crime rate and each characteristic:

| Characteristic | Correlation (r) | Strength |
|---|---|---|
| **IRSD score** | **−0.35** | **Moderate (strongest)** |
| Unemployment rate | +0.31 | Moderate |
| Median weekly household income | −0.24 | Weak to moderate |
| IEO score (education and occupation) | −0.16 | Weak |
| Volunteering rate | −0.15 | Weak |
| Year 12 completion rate | −0.12 | Weak |
| ADF service rate | −0.04 | Negligible |

*Correlation (r) ranges from −1 to +1. A negative value means the two move in
opposite directions: for IRSD, a higher score (less disadvantage) goes with a
lower crime rate.*

- **IRSD shows the strongest link**, ahead of unemployment and income on their
  own. This supports using one combined measure of disadvantage as the main
  finding.
- **Unemployment and income overlap**, because areas with high unemployment tend
  to have lower incomes. Their results are not two separate confirmations of the
  same effect. Separating them would need a multiple regression, which is beyond
  the scope of this SQL analysis.
- **Checking the education result:** the Year 12 completion rate first showed
  almost no link (−0.06), while the ABS's education and occupation index (IEO)
  showed a clearer one (−0.16). That gap pointed to a measurement problem: the
  Year 12 rate was dividing people aged 15+ by the total population, children
  included. Using the population aged 15+ as the denominator doubled the
  correlation to −0.12, in line with IEO. Education on its own still has only a
  weak link. IEO also overlaps with IRSD, so it can't show education's separate
  effect.
- **ADF service history** showed a negligible link. A suburb-wide share of
  residents who have served is too blunt to test what research on veterans
  actually looks at, such as combat exposure and individual-level offending.

### Supporting view: crime rates rise with unemployment

Suburbs split into four equal groups by unemployment rate:

| Unemployment quartile | Suburbs | Average unemployment | Pooled rate per 100K | Average rate per 100K |
|---|---|---|---|---|
| 1 (lowest) | 394 | 2.4% | 3,793 | 4,245 |
| 2 | 393 | 3.7% | 6,383 | 6,123 |
| 3 | 393 | 4.9% | 7,453 | 7,751 |
| 4 (highest) | 393 | 7.7% | 13,556 | 12,098 |

- The rate rises at every step from the lowest to the highest quartile.
- **Highest vs lowest quartile: 3.6× (pooled rate), 2.9× (average rate).**

### Robustness check: the result holds at different population floors

The unemployment analysis was repeated at four population floors:

| Population floor | Suburbs | Correlation (r) | Highest vs lowest quartile (average rate) |
|---|---|---|---|
| 500 | 1,573 | 0.31 | 2.85× |
| 1,000 | 1,264 | 0.34 | 2.97× |
| 2,000 | 962 | 0.42 | 3.47× |
| 5,000 | 513 | 0.38 | 3.08× |

- The direction and size of the link are similar at every floor: a moderate
  positive correlation, and roughly 3 times the crime rate in the highest-
  unemployment quartile.
- The link is slightly weaker at lower floors, as expected, because small
  suburbs have noisier rates.

**This is correlation, not causation.** These results show which suburb
characteristics move together with recorded crime rates, not what causes crime.

---

## Limitations

**Data**
- **Recorded crime only.** Figures reflect what was reported to or detected by
  police. Reporting and policing levels vary between areas and over time.
- **0.4% of NSW incidents have no suburb** (81,408 of 21,365,765), so suburb
  totals are slightly below the NSW total.
- **Category and recording changes.** Laws, policing priorities and recording
  practices changed over 30 years, which affects comparisons between 1995–1997 and
  2023–2025. Coercive control only became an offence in July 2024, so it has no
  earlier history.
- **COVID-19 rule enforcement.** "Other offences" spiked in 2020 and especially
  2021, most likely from public health order breaches. This inflates the
  all-offences totals for those years.
- **2026 is partial** (January to June) and is excluded from yearly comparisons.


**Method**
- **One census year.** Per-capita and socioeconomic results use 2021 only. They
  show a snapshot, not a trend over time.
- **Rates are per resident.** CBD and commercial areas have many visitors but few
  residents, which raises their rates.
- **Population floors.** Suburbs with 500 or fewer residents are excluded from
  the rate analysis (4.2% of the population), and suburbs with 2,000 or fewer
  from the top-10 rate lists (12.3%).
- **SEIFA coverage.** 222 suburbs have no SEIFA score and 9 have no IRSD score.
  All are very small, and none have more than 1,358 residents.
- **SEIFA deciles rank areas across all of Australia**, not just NSW, so the
  number of NSW suburbs in each decile varies (101 to 306).
- **Overlapping measures.** IRSD, IEO, unemployment and income are built from
  related census data, so they can't show each factor's separate effect.
- **ABS privacy adjustments.** The ABS adds small random changes to census table
  values to protect privacy. In very small areas this can make a subgroup larger
  than its total (e.g. more Year 12 completions than residents aged 15+). All
  affected areas have 53 or fewer residents and are excluded by the population
  floors.
