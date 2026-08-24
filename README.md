# Subscription Health & Revenue Retention Analytics — RavenStack SaaS

**A full-stack data analysis project — Excel → SQL → Power BI — investigating churn, revenue concentration, and retention risk for a simulated B2B SaaS company.**

---

## Business Problem

RavenStack is a mid-market B2B SaaS company selling project-management/collaboration software across three pricing tiers (Basic, Pro, Enterprise). Revenue looks healthy on the surface, but churn has been creeping up, and no single view ties together billing data, product usage, and support experience to explain *why* accounts are leaving.

**Stakeholders:** VP of Customer Success, Head of RevOps/Finance, Head of Support, and plan/product leads.

**Key questions this project answers:**
- Which plan tiers, industries, and countries have the highest churn?
- Is there a usage or support signal that shows up before an account churns?
- How much revenue is actually at risk?
- Which customers should Customer Success prioritize right now?

**Scope:** Descriptive and diagnostic analysis of historical account, subscription, usage, and support data. This is not a predictive ML model — a rule-based, fully explainable risk score is used instead, which is appropriate at this stage and more defensible in a business setting.

---

## Approach

This project follows a real analyst workflow — not just a Power BI dashboard, but the full pipeline an analyst would actually use when handed raw exports:

1. **Excel** — initial data audit (row counts, duplicates, nulls, sanity checks) before trusting the data enough to model it
2. **SQL (PostgreSQL)** — schema creation, data loading, and 7 sections of exploratory analysis: churn segmentation, revenue analysis, cohort/tenure analysis, feature usage & support correlation, and window-function-based queries (ROW_NUMBER, RANK, LAG, LEAD)
3. **Power BI** — star-schema data model, DAX measure library, and a 10-page interactive dashboard including a rule-based Customer Risk scoring system, a what-if churn scenario simulator, and drillthrough customer profiles

---

## Key Findings & Recommendations

### 1. Plan tier is not a meaningful churn driver
Churn rate is nearly identical across all three tiers — Enterprise (22.08%), Basic (22.02%), Pro (21.91%). The spread is under 0.2 points, which is noise, not signal.

**Recommendation:** Deprioritize plan-tier-specific retention campaigns — this isn't where the problem lives.

### 2. Churn is concentrated by industry and geography — not by product usage or support experience
- **DevTools** industry churns at **30.97%**, well above the ~22% baseline elsewhere.
- **Germany (DE)** churns at **32%**, the highest of any country.
- Meanwhile, product usage, error rates, and support experience show **almost no difference** between churned and active accounts: churned accounts actually averaged slightly *higher* usage (522.0 vs. 495.1 for active), identical error rates (28.2 vs. 28.2), and equivalent support ticket volume and satisfaction (4.0 tickets / 4.0 satisfaction vs. 4.08 / 3.95).

**Recommendation:** This rules out "fix the product" or "fix support" as the primary lever. Prioritize a qualitative deep-dive — account-manager interviews or targeted outreach — with DevTools and Germany-based accounts specifically, since this is where the real, ~10-point-above-baseline churn gap actually lives.

### 3. Revenue is fairly evenly distributed — no single whale dependency
The top 45% of accounts (by MRR) generate ~80% of total recurring revenue — a much flatter distribution than the classic "20% drives 80%" SaaS pattern.

**Recommendation:** Retention strategy can stay broad-based rather than requiring an account-by-account, white-glove approach for a handful of mega-accounts.

### 4. Billing frequency is a real risk signal
Monthly-billing customers are disproportionately represented among at-risk accounts compared to annual-billing customers.

**Recommendation:** Offer a targeted incentive for monthly customers — particularly within the at-risk population — to convert to annual billing. Lower switching friction on monthly plans appears to correlate with higher churn risk.

### 5. The current risk model flags very few High Risk accounts (a stated limitation, not a hidden one)
Of ~500 accounts, the rule-based Customer Risk Score currently classifies 498 as Low Risk, 2 as Medium Risk, and 0 as High Risk — total At-Risk MRR of ~₹9K.

This is worth stating directly: the model's signals (billing frequency, tenure, usage-vs-average, error count) lean heavily on usage and errors — exactly the two factors Finding 2 showed *don't* actually differentiate churned from active accounts. The model is likely under-weighting the segments (industry, geography) that showed the strongest real signal in this analysis.

**Recommendation (future work):** Incorporate industry and country as explicit risk-scoring inputs in a future iteration.

---

## Dashboard Overview

A 10-page Power BI report, including:
- **Executive Summary** — MRR, NRR, churn KPIs with a field-parameter toggle between MRR view and customer-count view
- **What-If Churn Scenario** — interactive slider simulating the MRR/ARR impact of reducing churn by 0–5 percentage points
- **Customer Risk** — rule-based risk scoring, at-risk MRR by plan tier and billing frequency, conditional-formatted risk table
- **Customer Profile (drillthrough)** — individual customer detail page with usage/error trend chart, reached by right-clicking any account in the Risk table
- **MRR Tooltip page** — hover-activated report-page tooltip showing plan-tier MRR breakdown
- Additional pages covering account detail, cohort structure, and supporting KPIs

---

## Tech Stack

| Layer | Tools |
|---|---|
| Data audit | Excel (PivotTables, XLOOKUP, SUMIFS/COUNTIFS, conditional formatting, What-If Data Tables) |
| Database & analysis | PostgreSQL — window functions, CTEs, conditional aggregation, joins across 5 tables |
| Modeling & visualization | Power BI — star schema, DAX (CALCULATE, FILTER, RANKX, time intelligence), field parameters, drillthrough, report-page tooltips |

---

## Repository Structure

```
ravenstack-subscription-analytics/
├── data/                  # raw CSV exports (accounts, subscriptions, feature_usage, support_tickets, churn_events)
├── excel/                 # data audit workbook (duplicates check, row counts, sanity totals, what-if analysis)
├── sql/                   # .sql files — schema creation + 01_exploratory_analysis.sql (7 sections)
├── powerbi/                # .pbix file
├── screenshots/            # PNG exports of each dashboard page
├── README.md                # this file
```

---

## Limitations

- Dataset is synthetic; findings reflect patterns in simulated data, not a live business.
- MRR movement classification (New/Expansion/Contraction/Churn) was scoped out of the SQL analysis — the `subscriptions` table is subscription-level, not a monthly billing ledger, so this metric would require assumptions the data doesn't cleanly support.
- The Customer Risk Score is a transparent, rule-based heuristic, not a statistically validated predictive model — appropriate for this stage, with clear next steps noted above.
- CAC and LTV:CAC are out of scope — no acquisition-cost data exists in this dataset.

---

## Author's Note

This project was built to demonstrate a full analyst workflow — not just dashboard-building, but the judgment calls that come before and after it: validating data before trusting it, knowing when a metric genuinely can't be calculated from the data available (and saying so), and distinguishing real signal (industry, geography, billing frequency) from noise (plan tier, usage, error rate) rather than forcing a story onto flat data.
