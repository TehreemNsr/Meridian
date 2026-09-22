# Meridian

**Early warning for rural US counties at risk of losing hospital-based obstetric care.**

Meridian ranks rural counties by their risk of losing their last hospital that delivers babies, so state health agencies can direct limited stabilization funding and outreach before a service closes rather than after. It is built end to end on Palantir Foundry: data pipelines, a three-object ontology, a logistic regression model, and batch inference written back to the ontology.

 **Author:** Tehreem Nasir

---

## Result

Validated on 2024 closures the model never saw during training:

| Metric | Value |
|---|---|
| Closures caught in the top 10% of ranked counties | **4 of 13** (1.3 expected by chance — **3.1× lift**) |
| Mean rank of actual closures (of 1,274) | **400** (chance: 637) |
| Median rank | 365 |
| Mean predicted score, counties that closed vs. did not | 0.575 vs. 0.404 |
| Test AUC-PR | 0.039 (base rate ≈ 0.010) |

**What this supports:** a screening list. Reviewing the top 127 counties would have surfaced roughly a third of the following year's closures.

**What this does not support:** identifying which specific county will close. Five of the thirteen closures ranked below the midpoint, and precision at any usable threshold is low. See [Limitations](#limitations).

---

## Problem

When a rural county loses its last hospital obstetric unit, the nearest delivery option can move an hour or more away. These closures are usually recognized only once they are announced, which leaves no time for intervention. Meridian asks whether public data can identify the counties most at risk a year ahead.

Scope is deliberately narrow:

- **Rural only** — non-metropolitan counties (no 2023 CBSA assignment), where a closure most often means no alternative within reach.
- **Hospital-based obstetric care only** — freestanding birth centres and midwifery practices are not in the outcome data.
- **County grain** — no public source records which individual obstetric unit closed, so the outcome is the county losing *all* hospital delivery capacity.

---

## Data

All sources are public.

| Source | Provides | Years used |
|---|---|---|
| HRSA Area Health Resources File (AHRF), 2019–2020 release | OB-GYN supply, age bands, population, births | 2010, 2015, 2018 |
| HRSA AHRF, 2024–2025 release | Same measures, current vintage | 2022, 2023 |
| University of Minnesota Rural Health Research Center | Annual county-level hospital obstetric status | 2010–2024 |
| HRSA Health Professional Shortage Areas | Primary care (HPSA) and maternity care (MCTA) shortage scores | 2023 |
| CMS Healthcare Cost Report Information System, processed panel ([Sacarny](https://github.com/asacarny/hospital-cost-reports)) | Hospital revenue, expenses, beds | 1997–2023 |
| CMS Provider of Services file, Q2 2026 | Hospital CCN → county FIPS crosswalk | current |

**Outcome label.** A closure event is a year-over-year transition in the county obstetric status series from "has hospital obstetric care" to "does not." 313 events occurred between 2011 and 2024.

---

## Architecture

```
Raw public files
   │  R (panel assembly, crosswalk trimming)
   ▼
Foundry datasets
   │  Pipeline Builder (cleaning, joins, derived features)
   ▼
Ontology: County ── ClosureEvent
             └──── Facility
   │
   ▼
Training table (county-year panel)
   │  Code Repository (Python transforms)
   ▼
feature_engineering → model_training → run_inference
   │
   ▼
Scores written back to County objects → Workshop application
```

### Ontology

| Object type | Primary key | Carries |
|---|---|---|
| **County** | `fips_st_cnty` | Workforce, shortage scores, births, population, rurality, `closure_probability` |
| **Facility** | `pn` (CMS Certification Number) | Hospital name, operating margin, beds |
| **ClosureEvent** | `event_id` (`{fips}_{year}`) | County and year of each loss of obstetric care |

Links: County → Facilities (one-to-many), County → Closure Events (one-to-many).

The ontology is scoped by three questions:

1. **Access impact** — which counties are most at risk, and how many births are affected?
2. **Compound fragility** — where do shortage designations, thin obstetric workforce, and negative hospital margins coincide?
3. **Pre-closure reconstruction** — what did a county look like in the years before it lost care?

---

## Method

### Panel and prediction windows

Features are observed in five AHRF years. Each observation year predicts closures in the interval before the next observation year, so every closure year from 2011 to 2024 is covered exactly once:

| Features observed | Closures predicted |
|---|---|
| 2010 | 2011–2015 |
| 2015 | 2016–2017 |
| 2018 | 2019–2022 |
| 2022 | 2023 |
| 2023 | 2024 |

The lead time varies from one to five years because it follows AHRF release spacing. Every predictor is measured before the outcome it predicts.

### Training table

6,612 rural county-years, 145 positive. The label is 1 if the county lost hospital obstetric care inside its window.

### Split

Temporal, not random. Train on observation years ≤ 2022; test on 2023, whose labels are the 2024 closures. A random split would place later years in training and leak future information into the score.

### Model

Logistic regression (`class_weight="balanced"`, standardized features) — chosen because its coefficients are signed and interpretable, which the compound-fragility question requires.

### Features

| Feature | Source | Coefficient (standardized) |
|---|---|---|
| `has_hospital` — county has a hospital filing a cost report | HCRIS + POS | +1.25 |
| `hpsa_score` — primary care shortage | HPSA | −0.52 |
| `mcta_score` — maternity care shortage | HPSA | +0.45 |
| `births_per_1000` | AHRF | +0.26 |
| `obgyn_55plus_share` — share of OB-GYNs aged 55+ | AHRF | +0.17 |
| `do_obgyn_pc` | AHRF | +0.17 |
| `obgyn_pc` | AHRF | −0.14 |
| `obgyn_tot` | AHRF | −0.17 |
| `min_margin` — worst hospital operating margin in the county | HCRIS | −0.12 |

---

## What the iterations showed

| Version | Features | Train AUC-PR |
|---|---|---|
| v3 | 7 county workforce and shortage features | 0.040 |
| v5 | + hospital presence | 0.047 |
| v6 (final) | + hospital operating margin | 0.052 |

County workforce and shortage data alone produced almost no signal. Adding facility-level hospital data raised train AUC-PR by 29%; removing margin while keeping hospital presence attributes roughly 60% of that lift to presence and 40% to margin. The model therefore supports the view that closure risk is driven more by hospital conditions than by county workforce counts — which is why the Facility object exists in the ontology.

---

## Limitations

- **Thirteen test events.** Every test metric moves materially if one county's rank changes.
- **Hospital presence dominates.** `has_hospital` is the largest coefficient, so counties whose hospital stopped filing cost reports score near zero even when they are the most distressed. Wilkes County, GA lost obstetric care in 2024 and ranked 1,059th of 1,274 for this reason.
- **Missing margin.** 30% of county-years have no hospital cost report. These are encoded as `has_hospital = 0` with margin set to 0, rather than dropped.
- **Shortage scores are 2023-only** and are applied to every observation year. They can explain differences between counties, not change within one.
- **Operating margin** is winsorized to [−1, 1]; extreme values came from hospitals reporting near-zero revenue. Short cost-reporting periods (4.5% of hospital-years) are excluded.
- **Crosswalk vintage.** The Q2 2026 Provider of Services file matched 99.96% of hospital-years to a county; 68 were unmatched and dropped.
- **Measurement differences across AHRF releases.** 2010–2018 births are annual totals and 2022–2023 are three-year averages; 2022 population uses the 2023 estimate.
- **Outcome scope.** Only hospital-based obstetric care is observed.

---

## Repository

```
transforms-model-training/
  src/main/
    model_training/
      feature_engineering.py   temporal split and feature selection
      model_training.py        logistic regression, published as a Foundry model
      run_inference.py         scores the 2023 test set, reports test AUC-PR
    model_adapters/
      adapter.py               input/output contract for the published model
r/
  build_ahrf_panel.R           five-year AHRF county panel
  build_pos_crosswalk.R        CCN → county FIPS crosswalk
ontology/
  object_types.md              County, Facility, ClosureEvent definitions and links
```

Pipeline Builder pipelines and the Workshop application live in Foundry and are documented in `ontology/` and the demo video.

---

## Author

Tehreem Nasir — Strategy & Analytics Analyst. Built as an independent project on Palantir Foundry.
