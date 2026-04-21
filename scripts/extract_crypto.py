import json
import os
from datetime import datetime, timezone
import psycopg2
import requests
from dotenv import load_dotenv
from psycopg2.extras import execute_values

load_dotenv()

COINGECKO_URL = os.getenv("URL", "https://api.coingecko.com/api/v3/coins/markets")
COINGECKO_API_KEY = os.getenv("COINGECKO_API_KEY")

# Env variables for local PostgreSQL connection.
DATABASE_USERNAME = os.getenv("DATABASE_USERNAME")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD")
DATABASE_HOST = os.getenv("DATABASE_HOST", "localhost")
DATABASE_PORT = os.getenv("DATABASE_PORT", "5432")
DATABASE_NAME = os.getenv("DATABASE_NAME")

def extract(url: str) -> list[dict]:
    headers = {}
    if COINGECKO_API_KEY:
        headers["x-cg-demo-api-key"] = COINGECKO_API_KEY

    params = {
        "vs_currency": "usd",
        "order": "market_cap_desc",
        "per_page": 50,
        "page": 1,
        "sparkline": "false",
        "price_change_percentage": "1h,24h",
    }

    response = requests.get(url, headers=headers, params=params, timeout=30)
    response.raise_for_status()

    data = response.json()
    if not isinstance(data, list):
        raise ValueError("Unexpected API response format. Expected a list of market rows.")

    return data


def transform(raw_rows: list[dict]) -> list[tuple]:
    extracted_at = datetime.now(timezone.utc)
    market_date = extracted_at.date()

    transformed_rows = []
    for row in raw_rows:
        transformed_rows.append(
            (
                extracted_at,
                market_date,
                row.get("id"),
                row.get("symbol"),
                row.get("name"),
                row.get("current_price"),
                row.get("market_cap"),
                row.get("total_volume"),
                row.get("price_change_percentage_1h_in_currency"),
                row.get("price_change_percentage_24h"),
                json.dumps(row),
            )
        )

    return transformed_rows


def _get_db_connection():
    missing = [
        key
        for key, value in {
            "DATABASE_USERNAME": DATABASE_USERNAME,
            "DATABASE_PASSWORD": DATABASE_PASSWORD,
            "DATABASE_NAME": DATABASE_NAME,
        }.items()
        if not value
    ]

    if missing:
        raise ValueError(f"Missing required environment variables: {', '.join(missing)}")

    return psycopg2.connect(
        dbname=DATABASE_NAME,
        user=DATABASE_USERNAME,
        password=DATABASE_PASSWORD,
        host=DATABASE_HOST,
        port=DATABASE_PORT,
    )


def load(rows: list[tuple]) -> int:
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS crypto_raw_data (
        load_id BIGSERIAL PRIMARY KEY,
        extracted_at TIMESTAMPTZ NOT NULL,
        market_date DATE NOT NULL,
        coin_id TEXT,
        symbol TEXT,
        name TEXT,
        current_price_usd NUMERIC,
        market_cap_usd NUMERIC,
        total_volume_usd NUMERIC,
        price_change_percentage_1h NUMERIC,
        price_change_percentage_24h NUMERIC,
        raw_payload JSONB NOT NULL,
        UNIQUE(market_date, coin_id)  -- Prevents duplicate entries for same coin on same day
    );
    """

    insert_sql = """
    INSERT INTO crypto_raw_data (
        extracted_at,
        market_date,
        coin_id,
        symbol,
        name,
        current_price_usd,
        market_cap_usd,
        total_volume_usd,
        price_change_percentage_1h,
        price_change_percentage_24h,
        raw_payload
    ) VALUES %s
    ON CONFLICT (market_date, coin_id) DO UPDATE SET
        extracted_at = EXCLUDED.extracted_at,
        current_price_usd = EXCLUDED.current_price_usd,
        market_cap_usd = EXCLUDED.market_cap_usd,
        total_volume_usd = EXCLUDED.total_volume_usd,
        price_change_percentage_1h = EXCLUDED.price_change_percentage_1h,
        price_change_percentage_24h = EXCLUDED.price_change_percentage_24h,
        raw_payload = EXCLUDED.raw_payload;
    """

    with _get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(create_table_sql)
            execute_values(cur, insert_sql, rows, template=None, page_size=100)
        conn.commit()

    return len(rows)


def main():
    raw_rows = extract(COINGECKO_URL)
    transformed_rows = transform(raw_rows)
    inserted_count = load(transformed_rows)
    print(f"Loaded {inserted_count} rows into crypto_raw_data.")


if __name__ == "__main__":
    main()

