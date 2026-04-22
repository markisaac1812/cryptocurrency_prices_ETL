SELECT
    {{ dbt_utils.generate_surrogate_key(['market_date', 'coin_id']) }} AS price_id,
    market_date,
    coin_id,  -- Foreign key to dim_coins
    current_price_usd,
    market_cap_usd,
    total_volume_usd,
    price_change_percentage_1h,
    price_change_percentage_24h,
    extracted_at
FROM {{ ref('stg_crypto_raw') }}