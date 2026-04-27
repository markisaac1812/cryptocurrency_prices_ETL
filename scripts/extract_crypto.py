import json
import os
from datetime import datetime, timezone
import psycopg2
import requests
from dotenv import load_dotenv
from psycopg2.extras import execute_values
import boto3
from botocore.exceptions import ClientError

load_dotenv()

# API Config
COINGECKO_URL = os.getenv("URL", "https://api.coingecko.com/api/v3/coins/markets")
COINGECKO_API_KEY = os.getenv("COINGECKO_API_KEY")

# AWS Config
AWS_REGION = os.getenv("AWS_REGION", "eu-central-1")
S3_BUCKET = os.getenv("S3_BUCKET_NAME")  

# Database Config (now pointing to AWS RDS)
DATABASE_USERNAME = os.getenv("DATABASE_USERNAME")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD")
DATABASE_HOST = os.getenv("DATABASE_HOST")  
DATABASE_PORT = os.getenv("DATABASE_PORT", "5432")
DATABASE_NAME = os.getenv("DATABASE_NAME", "crypto_db")


def extract(url: str) -> list[dict]:
    """Extract data from CoinGecko API"""
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

    print(f"✅ Extracted {len(data)} coins from API")
    return data


def upload_to_s3(data: list[dict], bucket: str, region: str) -> str:
    """Upload raw JSON to S3"""
    if not bucket:
        print("⚠️  S3_BUCKET_NAME not set, skipping S3 upload")
        return None
    
    s3_client = boto3.client('s3', region_name=region)
    
    # Create filename with timestamp
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d_%H-%M-%S")
    s3_key = f"raw/crypto/{timestamp}.json"
    
    try:
        # Upload JSON
        s3_client.put_object(
            Bucket=bucket,
            Key=s3_key,
            Body=json.dumps(data, indent=2),
            ContentType='application/json'
        )
        print(f"✅ Uploaded to S3: s3://{bucket}/{s3_key}")
        return s3_key
    except ClientError as e:
        print(f"❌ S3 upload failed: {e}")
        raise


def transform(raw_rows: list[dict]) -> list[tuple]:
    """Transform raw API data into database rows"""
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

    print(f"✅ Transformed {len(transformed_rows)} rows")
    return transformed_rows


def _get_db_connection():
    """Create connection to AWS RDS PostgreSQL"""
    missing = [
        key
        for key, value in {
            "DATABASE_USERNAME": DATABASE_USERNAME,
            "DATABASE_PASSWORD": DATABASE_PASSWORD,
            "DATABASE_HOST": DATABASE_HOST,
            "DATABASE_NAME": DATABASE_NAME,
        }.items()
        if not value
    ]

    if missing:
        raise ValueError(f"Missing required environment variables: {', '.join(missing)}")

    print(f"🔌 Connecting to RDS: {DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_NAME}")
    
    return psycopg2.connect(
        dbname=DATABASE_NAME,
        user=DATABASE_USERNAME,
        password=DATABASE_PASSWORD,
        host=DATABASE_HOST,
        port=DATABASE_PORT,
    )


def load(rows: list[tuple]) -> int:
    """Load data into AWS RDS PostgreSQL"""
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
        UNIQUE(market_date, coin_id)
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

    print(f"✅ Loaded {len(rows)} rows into RDS")
    return len(rows)


def main():
    """Main ETL pipeline"""
    print("=" * 60)
    print("🚀 Starting Crypto ETL Pipeline (AWS Version)")
    print("=" * 60)
    
    # Extract
    raw_rows = extract(COINGECKO_URL)
    
    # Upload to S3 (raw backup)
    if S3_BUCKET:
        upload_to_s3(raw_rows, S3_BUCKET, AWS_REGION)
    
    # Transform
    transformed_rows = transform(raw_rows)
    
    # Load to RDS
    inserted_count = load(transformed_rows)
    
    print("=" * 60)
    print(f"✅ Pipeline complete! Loaded {inserted_count} rows")
    print("=" * 60)


if __name__ == "__main__":
    main()
