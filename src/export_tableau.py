"""Build the Tableau-ready CSVs from the raw Olist files.

Reads the Kaggle CSVs in data/raw/ and writes three files to tableau/data/:
  olist_orders.csv     one row per order
  olist_customers.csv  one row per customer (customer_unique_id)
  olist_sellers.csv    one row per seller

Definitions match the SQL in sql/ and the published dashboard:
  - valid order: status is not 'canceled' or 'unavailable'
  - item revenue: sum of order_items.price (no freight)
  - delivery metrics: status 'delivered' with a delivered date
  - on time: delivered on or before the estimated (promised) date
  - review: average review score per order
  - main category: category of the order's most expensive item

Run from the repo root:  python src/export_tableau.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

from olist_common import pretty

BASE_DIR = Path(__file__).resolve().parent.parent
RAW = BASE_DIR / "data" / "raw"
OUT = BASE_DIR / "tableau" / "data"
OUT.mkdir(parents=True, exist_ok=True)

STATES = {
    "AC": ("Acre", "North"), "AL": ("Alagoas", "Northeast"), "AP": ("Amapá", "North"),
    "AM": ("Amazonas", "North"), "BA": ("Bahia", "Northeast"), "CE": ("Ceará", "Northeast"),
    "DF": ("Distrito Federal", "Center-West"), "ES": ("Espírito Santo", "Southeast"),
    "GO": ("Goiás", "Center-West"), "MA": ("Maranhão", "Northeast"), "MT": ("Mato Grosso", "Center-West"),
    "MS": ("Mato Grosso do Sul", "Center-West"), "MG": ("Minas Gerais", "Southeast"),
    "PA": ("Pará", "North"), "PB": ("Paraíba", "Northeast"), "PR": ("Paraná", "South"),
    "PE": ("Pernambuco", "Northeast"), "PI": ("Piauí", "Northeast"), "RJ": ("Rio de Janeiro", "Southeast"),
    "RN": ("Rio Grande do Norte", "Northeast"), "RS": ("Rio Grande do Sul", "South"),
    "RO": ("Rondônia", "North"), "RR": ("Roraima", "North"), "SC": ("Santa Catarina", "South"),
    "SP": ("São Paulo", "Southeast"), "SE": ("Sergipe", "Northeast"), "TO": ("Tocantins", "North"),
}
BANDS = ["On time or early", "1–3 days late", "4–7 days late", "8+ days late"]


def load(name: str, **kw) -> pd.DataFrame:
    path = RAW / f"{name}.csv"
    if not path.exists():
        raise SystemExit(f"Missing {path}. Download the Kaggle dataset into data/raw/ first.")
    return pd.read_csv(path, **kw)


ts = ["order_purchase_timestamp", "order_delivered_customer_date", "order_estimated_delivery_date"]
orders = load("olist_orders_dataset", parse_dates=ts)
customers = load("olist_customers_dataset")
items = load("olist_order_items_dataset")
products = load("olist_products_dataset")
translation = load("product_category_name_translation")
reviews = load("olist_order_reviews_dataset")
payments = load("olist_order_payments_dataset")

# ---- orders ----
o = orders.merge(customers[["customer_id", "customer_unique_id", "customer_state"]], on="customer_id", how="left")
o["valid_order"] = (~o.order_status.isin(["canceled", "unavailable"])).astype(int)

it = (items.merge(products[["product_id", "product_category_name"]], on="product_id", how="left")
           .merge(translation, on="product_category_name", how="left"))
it["category"] = (it.product_category_name_english.fillna(it.product_category_name)
                  .fillna("uncategorized").map(pretty))
main_cat = (it.sort_values(["order_id", "price"], ascending=[True, False])
              .drop_duplicates("order_id")[["order_id", "category"]])
per_order = items.groupby("order_id").agg(items=("order_item_id", "count"),
                                          item_revenue=("price", "sum"),
                                          freight=("freight_value", "sum")).reset_index()
o = o.merge(main_cat, on="order_id", how="left").merge(per_order, on="order_id", how="left")

delivered = (o.order_status == "delivered") & o.order_delivered_customer_date.notna()
days = (o.order_delivered_customer_date - o.order_purchase_timestamp).dt.total_seconds() / 86400
vs_promise = (o.order_delivered_customer_date - o.order_estimated_delivery_date).dt.total_seconds() / 86400
o["delivery_days"] = days.where(delivered)
o["days_vs_promise"] = vs_promise.where(delivered)
o["on_time_flag"] = (o.days_vs_promise <= 0).astype(float).where(o.days_vs_promise.notna())
band = np.select([o.days_vs_promise <= 0, o.days_vs_promise <= 3, o.days_vs_promise <= 7], BANDS[:3], BANDS[3])
o["delivery_band"] = pd.Series(band, index=o.index).where(o.days_vs_promise.notna())

score = reviews.groupby("order_id").review_score.mean().rename("review_score")
o = o.join(score, on="order_id")

out = pd.DataFrame({
    "order_id": o.order_id,
    "purchase_date": o.order_purchase_timestamp.dt.strftime("%Y-%m-%d"),
    "purchase_month": o.order_purchase_timestamp.dt.strftime("%Y-%m-01"),
    "year": o.order_purchase_timestamp.dt.year,
    "order_status": o.order_status,
    "valid_order": o.valid_order,
    "customer_unique_id": o.customer_unique_id,
    "customer_state": o.customer_state,
    "state_name": o.customer_state.map(lambda s: STATES[s][0]),
    "region": o.customer_state.map(lambda s: STATES[s][1]),
    "country": "Brazil",
    "main_category": o.category.fillna("No item data"),
    "items": o["items"].fillna(0).astype(int),
    "item_revenue": o.item_revenue.fillna(0).round(2),
    "freight": o.freight.fillna(0).round(2),
    "delivered_flag": delivered.astype(int),
    "delivery_days": o.delivery_days.round(2),
    "days_vs_promise": o.days_vs_promise.round(2),
    "delivery_band": o.delivery_band,
    "delivery_band_order": o.delivery_band.map({b: i + 1 for i, b in enumerate(BANDS)}).astype("Int64"),
    "on_time_flag": o.on_time_flag.astype("Int64"),
    "late_flag": (1 - o.on_time_flag).astype("Int64"),
    "review_score": o.review_score.round(2),
    "low_review_flag": (o.review_score <= 2).astype(float).where(o.review_score.notna()).astype("Int64"),
})
out.to_csv(OUT / "olist_orders.csv", index=False)

# ---- customers ----
counts = o.groupby("customer_unique_id").order_id.nunique()
first = o.groupby("customer_unique_id").order_purchase_timestamp.min()
first_state = o.sort_values("order_purchase_timestamp").groupby("customer_unique_id").customer_state.first()
order_value = payments.groupby("order_id").payment_value.sum().rename("order_value")
paid = o[o.valid_order == 1].join(order_value, on="order_id", how="inner")
last_purchase = orders.order_purchase_timestamp.max()
rec = paid.groupby("customer_unique_id").agg(last=("order_purchase_timestamp", "max"), total_spent=("order_value", "sum"))
rec["days_since_last_order"] = ((last_purchase - rec["last"]).dt.total_seconds() / 86400).astype(int)
rec["recency_segment"] = pd.cut(rec.days_since_last_order, [-1, 90, 180, 365, 10**6],
                                labels=["Active", "Cooling", "At risk", "Churned"]).astype(str)
cust = pd.DataFrame({
    "customer_unique_id": counts.index,
    "first_order_month": first.reindex(counts.index).dt.strftime("%Y-%m-01").values,
    "orders": counts.values,
    "repeat_flag": (counts.values >= 2).astype(int),
    "first_state": first_state.reindex(counts.index).values,
})
cust = cust.merge(rec[["days_since_last_order", "recency_segment", "total_spent"]].reset_index(),
                  on="customer_unique_id", how="left")
cust["total_spent"] = cust.total_spent.round(2)
cust["days_since_last_order"] = cust.days_since_last_order.astype("Int64")
cust.to_csv(OUT / "olist_customers.csv", index=False)

# ---- sellers ----
valid_items = items[items.order_id.isin(o.loc[o.valid_order == 1, "order_id"])]
sellers = (valid_items.groupby("seller_id").agg(item_revenue=("price", "sum"), orders=("order_id", "nunique"))
           .sort_values("item_revenue", ascending=False).reset_index())
sellers["item_revenue"] = sellers.item_revenue.round(2)
sellers["revenue_rank"] = range(1, len(sellers) + 1)
sellers.to_csv(OUT / "olist_sellers.csv", index=False)

# ---- checks: these must match the dashboard ----
v = out[out.valid_order == 1]
rev = sellers.item_revenue.to_numpy()
share = np.cumsum(rev) / rev.sum()
print(f"Orders (valid):        {len(v):,}            expect 98,207")
print(f"Item revenue:          R${v.item_revenue.sum():,.0f}   expect R$13,494,401")
print(f"On-time rate:          {v.on_time_flag.mean():.1%}             expect 91.9%")
print(f"Average review:        {v.review_score.mean():.2f}              expect 4.12")
print(f"Repeat rate:           {cust.repeat_flag.mean():.2%}             expect 3.12%")
print(f"Top 15 sellers share:  {rev[:15].sum() / rev.sum():.1%}             expect 17.6%")
print(f"Sellers making 80%:    {(np.searchsorted(share, 0.8) + 1) / len(rev):.1%}             expect 17.7%")
print(f"\nWrote {len(out):,} orders, {len(cust):,} customers, {len(sellers):,} sellers -> {OUT}")
