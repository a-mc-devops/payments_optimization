SELECT
    pa.attempt_id,
    pa.payment_id,
    pa.attempt_number,
    pa.initiated_by,
    pa.shop_id,
    pa.attempted_at,
    pa.amount_eur,
    pa.card_country,
    pa.card_type,
    pa.bank_id,
    pa.three_ds_used,
    pa.outcome,
    pa.decline_type,
    sh.shop_country,
    sh.business_type,
    sh.shop_fee_pct,
    sh.shop_fixed_fee_eur,
    sh.retries_on_date,
    sh.three_ds_policy,
    sh.three_ds_threshold_eur,
    DATE(pa.attempted_at) AS attempt_date,
    pa.outcome = 'approved' AS is_approved,
    CASE
        WHEN pa.card_country = sh.shop_country THEN 'domestic'
        WHEN pa.card_country IN ('NL', 'DE', 'FR', 'ES') THEN 'other_eu'
        WHEN pa.card_country IN ('UK', 'US') THEN 'non_eu'
    END AS card_region

    
FROM {{ ref('stg_payment_attempts') }} AS pa
JOIN {{ ref('stg_shops') }} AS sh
    ON pa.shop_id = sh.shop_id