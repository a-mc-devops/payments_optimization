WITH sales AS(
    SELECT
        ROUND((amount_eur * shop_fee_pct/100) + shop_fixed_fee_eur, 2) AS shop_price_eur,
        ROUND((amount_eur * bank_fee_pct/100) + bank_fixed_fee_eur, 2) AS expected_bank_fee_eur,
        ROUND(CASE WHEN (three_ds_used is FALSE AND fraud_report_id IS NOT NULL) THEN (amount_eur + 20) ELSE 0 END, 2) AS guarantee_cost_eur,
        i_at.attempt_id,
        i_at.payment_id,
        i_at.shop_id,
        i_at.bank_id,
        i_at.business_type,
        i_at.attempt_date,
        i_at.amount_eur,
        i_at.card_type,
        i_at.card_region,
        i_at.three_ds_used,
        i_at.shop_fee_pct,
        i_at.shop_fixed_fee_eur,
        s_fee.bank_fee_pct,
        s_fee.bank_fixed_fee_eur,
        s_fee.valid_from AS fee_rule_valid_from,
        s_fr.fraud_report_id
    FROM {{ ref('int_attempts') }} AS i_at
    LEFT JOIN {{ ref('stg_fee_rules') }} AS s_fee
        ON i_at.bank_id = s_fee.bank_id
        AND i_at.card_type   = s_fee.card_type
        AND i_at.card_region = s_fee.card_region
        AND i_at.attempt_date >= s_fee.valid_from
        AND (s_fee.valid_to IS NULL OR i_at.attempt_date <= s_fee.valid_to)
    LEFT JOIN {{ ref('stg_fraud_reports')}} AS s_fr
        ON i_at.attempt_id = s_fr.attempt_id
    WHERE i_at.outcome = 'approved'
)

SELECT
    shop_price_eur - expected_bank_fee_eur - guarantee_cost_eur AS platform_margin_eur,
    *
FROM sales
