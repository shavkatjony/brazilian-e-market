import sqlite3
from pathlib import Path
import pandas as pd

# Anchor everything to this script's location, not the terminal's cwd.
# This is the actual fix for your "unable to open database file" error.
BASE_DIR = Path(__file__).resolve().parent.parent   # -> brazilian-e-market/
DATA_RAW = BASE_DIR / "data" / "raw"
DB_PATH = BASE_DIR / "data" / "olist.db"

# Make sure the folder exists before sqlite tries to write into it
DATA_RAW.mkdir(parents=True, exist_ok=True)

conn = sqlite3.connect(DB_PATH)

datasets = {
    "customers": DATA_RAW / "olist_customers_dataset.csv",
    "geolocation": DATA_RAW / "olist_geolocation_dataset.csv",
    "order_items": DATA_RAW / "olist_order_items_dataset.csv",
    "payments": DATA_RAW / "olist_order_payments_dataset.csv",
    "reviews": DATA_RAW / "olist_order_reviews_dataset.csv",
    "orders": DATA_RAW / "olist_orders_dataset.csv",          # fixed: was missing the 's'
    "products": DATA_RAW / "olist_products_dataset.csv",
    "sellers": DATA_RAW / "olist_sellers_dataset.csv",
    "category_translation": DATA_RAW / "product_category_name_translation.csv",
}

for table_name, file_path in datasets.items():
    if not file_path.exists():
        print(f"SKIPPED {table_name}: file not found at {file_path}")
        continue
    df = pd.read_csv(file_path)
    df.to_sql(table_name, conn, if_exists="replace", index=False)
    print(f"{table_name}: {len(df):,} rows loaded")

conn.close()
print("\nDone ->", DB_PATH)