"""Rebuild the data files behind the live dashboard (docs/data/*.json).

Run from the repo root after the Kaggle CSVs are in data/raw/:
    python3 src/build_web_data.py

docs/data/state_shapes.json (Brazil state outlines from IBGE) is static and
is not rebuilt here.
"""
import itertools
import json
import math

import numpy as np
import pandas as pd

from olist_common import BANDS, BASE_DIR, STATES, order_facts

OUT = BASE_DIR / "docs" / "data"
OUT.mkdir(parents=True, exist_ok=True)


def with_all(df, cols):
    """Repeat the rows once per subset of cols, with the left-out cols set to 'All'."""
    parts = []
    for k in range(len(cols) + 1):
        for keep in itertools.combinations(cols, k):
            d = df.copy()
            for col in cols:
                if col not in keep:
                    d[col] = "All"
            parts.append(d)
    return pd.concat(parts, ignore_index=True)


def rnd(x, n):
    return None if x is None or (isinstance(x, float) and math.isnan(x)) else round(float(x), n)


def dump(name, rows):
    if isinstance(rows, pd.DataFrame):
        rows = json.loads(rows.to_json(orient="records", force_ascii=False))
    path = OUT / name
    path.write_text(json.dumps(rows, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{name:24s} {len(rows):>7,} rows")


o, orders, items, payments = order_facts()
v = o[o.valid].copy()
v["late"] = (1.0 - v.on_time).fillna(0.0)

# Scorecard: year x state x category, each with an All row
base = v[["order_id", "year", "customer_state", "category", "revenue", "delivered", "delivery_days",
          "on_time", "late", "review", "low_review"]].rename(columns={"customer_state": "state"})
g = with_all(base, ["year", "state", "category"]).groupby(["year", "state", "category"])
sc = pd.DataFrame({
    "orders": g.order_id.count(), "revenue": g.revenue.sum(), "delivered": g.delivered.sum(),
    "avg_delivery_days": g.delivery_days.mean(), "on_time_rate": g.on_time.mean(),
    "late_orders": g.late.sum(), "reviewed": g.review.count(), "avg_review": g.review.mean(),
    "low_review_share": g.low_review.mean(),
}).reset_index()
sc["revenue_per_order"] = sc.revenue / sc.orders
sc["state_name"] = sc.state.map(lambda s: STATES[s][0] if s in STATES else "All states")
sc["region"] = sc.state.map(lambda s: STATES[s][1] if s in STATES else "All")
for col, n in [("revenue", 2), ("avg_delivery_days", 2), ("on_time_rate", 4), ("avg_review", 2),
               ("low_review_share", 4), ("revenue_per_order", 2)]:
    sc[col] = sc[col].map(lambda x: rnd(x, n))
sc["delivered"] = sc.delivered.astype(int)
sc["late_orders"] = sc.late_orders.round().astype(int)
sc = sc[["year", "state", "state_name", "region", "category", "orders", "revenue", "revenue_per_order",
         "delivered", "avg_delivery_days", "on_time_rate", "late_orders", "reviewed", "avg_review",
         "low_review_share"]].sort_values(["year", "state", "category"])
dump("scorecard.json", sc)

# Reviews by lateness band
b = o[o.delivered & o.review.notna() & o.band.notna()]
b = b[["order_id", "year", "customer_state", "category", "band", "review", "low_review"]].rename(
    columns={"customer_state": "state"})
gb = with_all(b, ["year", "state", "category"]).groupby(["year", "state", "category", "band"])
bands = pd.DataFrame({"orders": gb.order_id.count(), "avg_review": gb.review.mean(),
                      "low_review_share": gb.low_review.mean()}).reset_index()
bands["share_of_orders"] = bands.orders / bands.groupby(["year", "state", "category"]).orders.transform("sum")
bands["band_order"] = bands.band.map({k: i + 1 for i, k in enumerate(BANDS)})
for col, n in [("avg_review", 2), ("low_review_share", 4), ("share_of_orders", 4)]:
    bands[col] = bands[col].map(lambda x: rnd(x, n))
bands = bands[["year", "state", "category", "band_order", "band", "orders", "share_of_orders", "avg_review",
               "low_review_share"]].sort_values(["year", "state", "category", "band_order"])
dump("delivery_bands.json", bands)

# Monthly trend: month x state x category
t = v[["order_id", "month", "customer_state", "category", "revenue", "on_time"]].rename(
    columns={"customer_state": "state"})
gt = with_all(t, ["state", "category"]).groupby(["month", "state", "category"])
trend = pd.DataFrame({"orders": gt.order_id.count(), "revenue": gt.revenue.sum(),
                      "on_time_rate": gt.on_time.mean()}).reset_index()
trend["revenue"] = trend.revenue.map(lambda x: rnd(x, 2))
trend["on_time_rate"] = trend.on_time_rate.map(lambda x: rnd(x, 4))
dump("monthly_trend.json", trend.sort_values(["state", "category", "month"]))

# Customers
counts = o.groupby("customer_unique_id").order_id.nunique()
first = o.groupby("customer_unique_id").order_purchase_timestamp.min()
seq = o.sort_values("order_purchase_timestamp").groupby("customer_unique_id").order_purchase_timestamp.apply(list)
gaps = [(x[1] - x[0]).total_seconds() / 86400 for x in seq if len(x) >= 2]
dump("overview.json", [{
    "orders_placed": int(len(o)), "valid_orders": int(len(v)), "customers": int(len(counts)),
    "repeat_customers": int((counts >= 2).sum()), "repeat_rate": rnd((counts >= 2).mean(), 4),
    "avg_days_to_second_order": rnd(float(np.mean(gaps)), 1), "sellers": int(items.seller_id.nunique()),
    "first_purchase": o.order_purchase_timestamp.min().strftime("%Y-%m-%d"),
    "last_purchase": o.order_purchase_timestamp.max().strftime("%Y-%m-%d"),
    "item_revenue": rnd(v.revenue.sum(), 2),
}])

value = payments.groupby("order_id").payment_value.sum().rename("order_value")
paid = o[o.valid].join(value, on="order_id", how="inner")
last = orders.order_purchase_timestamp.max()
cr = paid.groupby("customer_unique_id").agg(last=("order_purchase_timestamp", "max"), spent=("order_value", "sum"))
cr["dsl"] = ((last - cr["last"]).dt.total_seconds() / 86400).astype(int)
cr["segment"] = pd.cut(cr.dsl, [-1, 90, 180, 365, 10**6], labels=["Active", "Cooling", "At risk", "Churned"])
seg = cr.groupby("segment", observed=False).agg(customers=("spent", "size"), avg_spend=("spent", "mean")).reset_index()
seg["share"] = (seg.customers / seg.customers.sum()).round(4)
seg["avg_spend"] = seg.avg_spend.round(2)
seg["segment_order"] = range(1, 5)
seg["window"] = ["Bought in the last 90 days", "91–180 days ago", "181–365 days ago", "More than a year ago"]
seg["segment"] = seg.segment.astype(str)
dump("recency_segments.json", seg[["segment_order", "segment", "window", "customers", "share", "avg_spend"]])

cf = pd.DataFrame({"first": first, "orders": counts})
cf["cohort_month"] = cf["first"].dt.strftime("%Y-%m")
coh = cf.groupby("cohort_month").agg(cohort_size=("orders", "size"),
                                     returned=("orders", lambda s: int((s >= 2).sum()))).reset_index()
coh["repeat_rate"] = (coh.returned / coh.cohort_size).round(4)
dump("cohorts.json", coh)

# Sellers
vi = items[items.order_id.isin(v.order_id)]
sel = vi.groupby("seller_id").agg(revenue=("price", "sum"), orders=("order_id", "nunique")).reset_index()
sel["revenue"] = sel.revenue.round(2)
dump("sellers.json", sel.sort_values("revenue", ascending=False))

print(f"\nDone -> {OUT}")
