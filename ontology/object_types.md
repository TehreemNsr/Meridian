# Meridian ontology

Three object types and two link types, defined in Foundry Ontology Manager.
This file documents them because ontology definitions are not stored as code.

---

## County

One object per US county. Carries workforce, shortage, demographic, and rurality
attributes, plus the model's `closure_probability`.

| | |
|---|---|
| Backing dataset | `county_scored` |
| Primary key | `fips_st_cnty` (5-character string, zero-padded) |
| Title property | `cnty_name` |
| Object count | 3,235 |

**Key properties**

| Property | Type | Meaning |
|---|---|---|
| `fips_st_cnty` | String | State + county FIPS code |
| `cnty_name`, `st_name`, `st_name_abbrev` | String | Names |
| `cbsa_23` | String | 2023 CBSA code; `NA` = non-metropolitan (rural) |
| `md_nf_obgyn_gen_23` | Integer | MD non-federal general OB-GYNs |
| `obgyn_55plus_share` | Double | Share of OB-GYNs aged 55+ |
| `obgyn_density` | Double | OB-GYNs per 100,000 population |
| `hpsa_score` | Integer | Primary care shortage score |
| `mcta_score` | Integer | Maternity care shortage score |
| `births_3yr_avg_23` | String | Three-year average births |
| `popn_est_23`, `popn_est_ge65_23` | Integer | Population estimates |
| `closure_probability` | Double | Model score; populated for scored rural counties, null otherwise |

---

## Facility

One object per hospital filing a Medicare cost report in 2023.

| | |
|---|---|
| Backing dataset | `ont_facility` |
| Primary key | `pn` (CMS Certification Number, 6-character string) |
| Title property | `facility_name` |
| Object count | 5,755 |

| Property | Type | Meaning |
|---|---|---|
| `pn` | String | CMS Certification Number |
| `fips_st_cnty` | String | County FIPS (foreign key to County) |
| `facility_name` | String | Hospital name |
| `operating_margin` | Double | (net patient revenue + other income - operating - other expenses) / (net patient revenue + other income), winsorized to [-1, 1] |
| `beds_total` | String | Total beds |
| `ayear` | Integer | Cost report year |

---

## ClosureEvent

One object per county-year in which the county lost hospital-based obstetric care.

| | |
|---|---|
| Backing dataset | `ont_closure_event` |
| Primary key | `event_id` (`{fips_st_cnty}_{event_year}`) |
| Title property | `event_id` |
| Object count | 313 (2011-2024) |

| Property | Type | Meaning |
|---|---|---|
| `event_id` | String | Composite key |
| `fips_st_cnty` | String | County FIPS (foreign key to County) |
| `event_year` | Integer | Year obstetric care was lost |
| `source_citation` | String | UMN Rural Health Research Center county obstetric status series |

---

## Link types

| Link | Cardinality | Join | API |
|---|---|---|---|
| County to Closure Events | One to many | ClosureEvent.`fips_st_cnty` to County.`fips_st_cnty` | `county.closureEvents.all()` / `closureEvent.county.get()` |
| County to Facilities | One to many | Facility.`fips_st_cnty` to County.`fips_st_cnty` | `county.facilities.all()` / `facility.county.get()` |

---

## Competency questions

The ontology is scoped to answer:

1. **Access impact:** which rural counties are most at risk of losing hospital obstetric care, and how many births are affected?
2. **Compound fragility:** where do shortage designations, thin obstetric workforce, and negative hospital margins coincide?
3. **Pre-closure state:** what condition was each county in during 2023, the year before it lost hospital obstetric care in 2024?
