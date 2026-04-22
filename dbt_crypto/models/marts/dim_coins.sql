WITH latest_coin_info AS (
    SELECT
        coin_id,
        symbol,
        name,
        ROW_NUMBER() OVER (PARTITION BY coin_id ORDER BY market_date DESC) AS rn
    FROM {{ ref('stg_crypto_raw') }}
)

SELECT
    coin_id,  
    symbol,
    name,
    CURRENT_TIMESTAMP AS updated_at
FROM latest_coin_info
WHERE rn = 1