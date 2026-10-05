SELECT
    shop_id,
    shop_name,
    country AS shop_country,
    business_type,
    fee_pct AS shop_fee_pct,
    fixed_fee_eur AS shop_fixed_fee_eur,
    retries_on_date,
    three_ds_policy,
    three_ds_threshold_eur
    
FROM {{ source('raw', 'shops') }}