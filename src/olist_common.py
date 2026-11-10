"""Shared loading and naming helpers for the export scripts."""
from pathlib import Path

import numpy as np
import pandas as pd

BASE_DIR = Path(__file__).resolve().parent.parent
RAW = BASE_DIR / "data" / "raw"

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

PRETTY = {
    "bed_bath_table": "Bed, bath & table", "health_beauty": "Health & beauty",
    "sports_leisure": "Sports & leisure", "computers_accessories": "Computers & accessories",
    "furniture_decor": "Furniture & decor", "watches_gifts": "Watches & gifts",
    "garden_tools": "Garden tools", "cool_stuff": "Cool stuff", "auto": "Auto",
    "home_appliances": "Home appliances", "home_appliances_2": "Home appliances 2",
    "fashion_bags_accessories": "Fashion bags & accessories", "food_drink": "Food & drink",
    "construction_tools_construction": "Construction tools", "small_appliances": "Small appliances",
    "pc_gamer": "PC gamer", "portateis_cozinha_e_preparadores_de_alimentos": "Portable kitchen appliances",
    "dvds_blu_ray": "DVDs & Blu-ray", "cds_dvds_musicals": "CDs, DVDs & musicals",
    "la_cuisine": "La cuisine", "fashion_male_clothing": "Fashion, men's clothing",
    "fashio_female_clothing": "Fashion, women's clothing", "fashion_childrens_clothes": "Fashion, children's clothes",
    "kitchen_dining_laundry_garden_furniture": "Kitchen, dining & garden furniture",
    "costruction_tools_garden": "Construction tools, garden", "costruction_tools_tools": "Construction tools, tools",
    "tablets_printing_image": "Tablets, printing & image", "books_general_interest": "Books, general interest",
    "books_technical": "Books, technical", "books_imported": "Books, imported",
    "art": "Art", "arts_and_craftmanship": "Arts & craftsmanship",
    "security_and_services": "Security & services", "signaling_and_security": "Signaling & security",
}


def pretty(cat: str) -> str:
    if cat in PRETTY:
        return PRETTY[cat]
    s = cat.replace("_", " ").strip()
    return s[:1].upper() + s[1:]


def load(name: str, **kw) -> pd.DataFrame:
    path = RAW / f"{name}.csv"
    if not path.exists():
        raise SystemExit(f"Missing {path}. Download the Kaggle dataset into data/raw/ first.")
    return pd.read_csv(path, **kw)


def order_facts():
    """One row per order with every field the dashboards use, plus the raw tables."""
    ts = ["order_purchase_timestamp", "order_delivered_customer_date", "order_estimated_delivery_date"]
    orders = load("olist_orders_dataset", parse_dates=ts)
    customers = load("olist_customers_dataset")
    items = load("olist_order_items_dataset")
    products = load("olist_products_dataset")
    translation = load("product_category_name_translation")
    reviews = load("olist_order_reviews_dataset")
    payments = load("olist_order_payments_dataset")

    o = orders.merge(customers[["customer_id", "customer_unique_id", "customer_state"]], on="customer_id", how="left")
    o["valid"] = ~o.order_status.isin(["canceled", "unavailable"])
    o["year"] = o.order_purchase_timestamp.dt.year.astype(str)
    o["month"] = o.order_purchase_timestamp.dt.strftime("%Y-%m")

    it = (items.merge(products[["product_id", "product_category_name"]], on="product_id", how="left")
               .merge(translation, on="product_category_name", how="left"))
    it["cat_raw"] = it.product_category_name_english.fillna(it.product_category_name).fillna("uncategorized")
    main_cat = (it.sort_values(["order_id", "price"], ascending=[True, False])
                  .drop_duplicates("order_id")[["order_id", "cat_raw"]])
    per_order = items.groupby("order_id").agg(revenue=("price", "sum"), items=("order_item_id", "count"),
                                              freight=("freight_value", "sum")).reset_index()
    o = o.merge(main_cat, on="order_id", how="left").merge(per_order, on="order_id", how="left")
    o["category"] = o.cat_raw.map(lambda x: "No item data" if pd.isna(x) else pretty(x))
    o["revenue"] = o.revenue.fillna(0.0)

    o["delivered"] = (o.order_status == "delivered") & o.order_delivered_customer_date.notna()
    days = (o.order_delivered_customer_date - o.order_purchase_timestamp).dt.total_seconds() / 86400
    vs = (o.order_delivered_customer_date - o.order_estimated_delivery_date).dt.total_seconds() / 86400
    o["delivery_days"] = days.where(o.delivered)
    o["days_vs_estimate"] = vs.where(o.delivered)
    o["on_time"] = (o.days_vs_estimate <= 0).astype(float).where(o.days_vs_estimate.notna())
    band = np.select([o.days_vs_estimate <= 0, o.days_vs_estimate <= 3, o.days_vs_estimate <= 7], BANDS[:3], BANDS[3])
    o["band"] = pd.Series(band, index=o.index).where(o.days_vs_estimate.notna())

    score = reviews.groupby("order_id").review_score.mean().rename("review")
    o = o.join(score, on="order_id")
    o["low_review"] = (o.review <= 2).astype(float).where(o.review.notna())
    return o, orders, items, payments
