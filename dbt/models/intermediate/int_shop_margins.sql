WITH 
    shop_sales AS(
        SELECT
            shop_id,
            business_type,
            shop_fee_pct,
            shop_fixed_fee_eur,
            COUNT(*) AS approved_payments_count,
            SUM(amount_eur) AS approved_sales_eur,
            SUM(CASE WHEN three_ds_used IS FALSE THEN amount_eur ELSE 0 END) AS sales_without_3ds_eur,
            SUM(shop_price_eur) AS shop_price_eur,
            SUM(expected_bank_fee_eur) AS expected_bank_fee_eur
        FROM {{ ref('int_approved_payments')}}
        GROUP BY shop_id, business_type, shop_fee_pct, shop_fixed_fee_eur
    )
    ,
    with_fraud AS(
        SELECT
            ss.*,
            ss.sales_without_3ds_eur * fc.fraud_cost_per_100_eur_low / 100 AS expected_fraud_cost_eur_low,
            ss.sales_without_3ds_eur * fc.fraud_cost_per_100_eur_best / 100 AS expected_fraud_cost_eur_best,
            ss.sales_without_3ds_eur * fc.fraud_cost_per_100_eur_high / 100 AS expected_fraud_cost_eur_high,

        FROM shop_sales AS ss
        JOIN {{ ref('int_fraud_cost_rates')}} AS fc
            ON ss.business_type = fc.business_type
    )
    ,
    with_margin AS (
        SELECT
            *,
            shop_price_eur - expected_bank_fee_eur - expected_fraud_cost_eur_high AS expected_margin_eur_low,
            shop_price_eur - expected_bank_fee_eur - expected_fraud_cost_eur_best AS expected_margin_eur_best,
            shop_price_eur - expected_bank_fee_eur - expected_fraud_cost_eur_low AS expected_margin_eur_high
        FROM with_fraud
    )

SELECT
    *,
    expected_margin_eur_low / approved_sales_eur * 100 AS expected_margin_per_100_eur_low,
    expected_margin_eur_best / approved_sales_eur * 100 AS expected_margin_per_100_eur_best,
    expected_margin_eur_high / approved_sales_eur * 100 AS expected_margin_per_100_eur_high
FROM with_margin