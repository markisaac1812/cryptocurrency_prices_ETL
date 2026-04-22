WITH source AS (
    SELECT * FROM {{ source('raw', 'crypto_raw_data') }}
),

cleaned AS (
    SELECT
        load_id,
        extracted_at,
        market_date,
        coin_id,
        LOWER(TRIM(symbol)) AS symbol,
        TRIM(name) AS name,
        current_price_usd,
        market_cap_usd,
        total_volume_usd,
        price_change_percentage_1h,
        price_change_percentage_24h
    FROM source
    WHERE coin_id IS NOT NULL
      AND name IS NOT NULL
)

SELECT * FROM cleaned