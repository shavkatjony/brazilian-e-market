# Brazilian E-Commerce: SQL-First Business Analysis

Analyzing ~99,000 orders from the Olist Brazilian E-Commerce dataset to answer
five operational questions — using SQL for extraction and Python for
visualization and interpretation. No machine learning: the goal is to turn raw
transaction data into decisions a business could act on.

**Headline findings:**
- Only **3.12%** of customers ever order again — the marketplace is structurally one-time-purchase.
- **Late delivery is the dominant driver of poor reviews**: on-time orders average 4.29 stars, orders 8+ days late average 1.73 — a 60% collapse.
- Delivery speed is severely uneven by region: the slowest state (Roraima) runs **2.3× the national average**.

---

## The Questions

1. **Customer retention** — how loyal is the base, and how many customers have gone quiet?
2. **Delivery vs. satisfaction** — do delivery delays actually lower review scores?
3. **Seller performance** — which sellers drive revenue, and is it concentrated or spread?
4. **Cohort retention** — do customers acquired in different months return at different rates?
5. **Logistics bottlenecks** — which regions experience the slowest deliveries?

The full narrative — question → context → SQL → chart → insight → recommendation
— lives in [`notebooks/analysis.ipynb`](notebooks/analysis.ipynb). The executive
one-pager is in [`reports/findings.md`](reports/findings.md).

---

## Key Findings

### 1. The base is one-time-purchase
70.7% of customers are already **At Risk** (41.4%) or **Churned** (29.3%);
only 10.1% are Active. At a 3.12% repeat rate, this is the normal shape of the
business, not a churn problem to fix.

![Customers by recency segment](reports/figures/at_risk_segments.png)

### 2. Late delivery destroys reviews
Review scores fall in near-perfect step with lateness — every additional band
costs roughly a full star.

![Average review score by delivery timeliness](reports/figures/delivery_vs_review.png)

### 3. Revenue is spread, not concentrated
The top 15 sellers account for only ~14.6% of GMV; the single largest is just
1.4%. The long tail carries the business — a resilience strength.

![Top 15 sellers by item revenue](reports/figures/seller_revenue.png)

### 4. Retention is uniformly low across every cohort
Flat at 3–5% from early 2017 onward. No acquisition period produced stickier
customers, confirming the one-time pattern is structural, not seasonal. (The
100% spike is a single-customer 2016 cohort and is disregarded.)

![Retention rate by acquisition cohort](reports/figures/cohort_retention.png)

### 5. Delivery collapses in the north
Against a 12.6-day national average, Roraima (29.4), Amapá (27.2), and Amazonas
(26.4) — all remote northern states far from the São Paulo seller base — are
the slowest. This is a last-mile/distance problem, not a nationwide one.

![15 slowest states by average delivery time](reports/figures/slowest_states.png)

---

## Recommendations

1. **Treat first-order delivery as the retention strategy.** Since customers
   rarely reorder, a late first delivery is often the customer's entire brand
   experience. Do *not* invest in loyalty programs — there is no repeat base to reward.
2. **Fix the northern-state logistics gap** (RR, AP, AM) with regional carrier
   partnerships or northern fulfilment.
3. **Monitor the on-time delivery rate weekly** — it maps directly onto the
   review score the marketplace depends on.

---

## Method & Tech

An SQL-first approach mirrors real-world data extraction: raw CSVs are loaded
into a SQLite database, SQL does the heavy lifting (CTEs, window functions,
joins, aggregation), and Python (pandas, matplotlib) handles visualization and
narrative synthesis.

**Stack:** SQLite · SQL · Python · pandas · matplotlib

**Data:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
— ~99K orders across 9 tables, Sept 2016 – Oct 2018.
*Raw CSVs and the built `.db` are gitignored to keep the repo lightweight; both
are regenerable from the ingestion script.*

---

## Repository Structure

```text
brazilian-e-market/
├── data/
│   ├── raw/                  # 9 Kaggle CSVs (gitignored)
│   └── olist.db              # SQLite database (gitignored — rebuildable)
├── src/
│   └── create_db.py          # builds olist.db from the CSVs
├── sql/
│   ├── 00_exploration.sql    # schema + data-quality checks
│   ├── 01_at_risk_customers.sql
│   ├── 02_delivery_vs_reviews.sql
│   ├── 03_seller_performance.sql
│   ├── 04_cohort_retention.sql
│   ├── 05_logistics_bottlenecks.sql
│   └── notebook/             # single-query files feeding the notebook charts
├── notebooks/
│   └── analysis.ipynb        # the full narrative analysis
├── reports/
│   ├── findings.md           # executive summary
│   └── figures/              # exported charts (300 DPI)
├── requirements.txt
├── .gitignore
└── README.md
```

---

## Reproduce It

```bash
# 1. clone and enter
git clone https://github.com/shavkatjony/brazilian-e-market.git
cd brazilian-e-market

# 2. install dependencies
pip install -r requirements.txt

# 3. download the dataset from Kaggle (https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) into data/raw/

# 4. build the database from the CSVs
python src/create_db.py

# 5. open the analysis
jupyter lab notebooks/analysis.ipynb
```

---

## Notes & Limitations

- Revenue uses `order_items.price` (item value), not payment totals, to avoid
  double-counting orders shared across sellers.
- Delivery metrics cover only completed deliveries with valid dates.
- Customers are identified by `customer_unique_id`, not the per-order `customer_id`.
- The data ends in Oct 2018; review scores are self-selected; acquisition cost
  is unknown — so "retention is low" is a strong signal, not a full ROI case.

---

*Analysis by Shavkatjon Yuldashev.*
*email: shavkatjon.yuldashev.0411@gmail.com*